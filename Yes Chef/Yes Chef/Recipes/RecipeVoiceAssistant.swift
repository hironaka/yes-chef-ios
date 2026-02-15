import SwiftUI
import RealtimeAPI
import AVFoundation

struct RecipeVoiceAssistant: View {
    @State private var conversation = Conversation()
    @State private var previousEntries: [Item] = []
    let recipe: Recipe
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Waveform(level: 0)
                .frame(height: 60)
        }
        .task {
            await initialConnect()
        }
        .task {
            // Debug: force disconnect after 60 seconds to test reconnection
            try? await Task.sleep(for: .seconds(15))
            await reconnect()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            conversation.muted = true
            try? conversation.send(event: .clearInputAudioBuffer())
            conversation.disconnect()
        }
    }
    
    private func initialConnect() async {
        do {
            if let token = await fetchToken() {
                try await conversation.connect(ephemeralKey: token)
                await conversation.waitForConnection()
                await sendSystemInstruction()
                await sendRecipe()
            } else {
                print("Failed to fetch token")
            }
        } catch {
            print("Failed to connect: \(error)")
        }
    }
    
    private func reconnect() async {
        print("Attempting to reconnect...")
        previousEntries = conversation.entries
        
        conversation.disconnect()
        
        // Create a fresh Conversation instance - the old WebRTCConnector's peer connection
        // cannot be reused after disconnect (connection state is no longer 'new')
        conversation = Conversation()
        
        do {
            if let token = await fetchToken() {
                try await conversation.connect(ephemeralKey: token)
                await conversation.waitForConnection()
                
                print("Reconnected successfully, sending system instruction...")
                await sendSystemInstruction()
                await sendRecipe()
                
                print("Replaying \(previousEntries.count) previous entries...")
                await replayConversationHistory()
                
                print("Reconnection complete")
            } else {
                print("Failed to fetch token for reconnection, dismissing")
                await MainActor.run {
                    onDismiss()
                }
                return
            }
        } catch {
            print("Reconnection failed: \(error), dismissing")
            await MainActor.run {
                onDismiss()
            }
            return
        }
    }
    
    private func replayConversationHistory() async {
        for entry in previousEntries {
            do {
                print("Conversation entry: \(entry)")
                if let validEntry = sanitizeForReplay(entry) {
                    print("Sanitized conversation entry: \(validEntry)")
                    try conversation.send(event: .createConversationItem(validEntry))
                } else {
                    print("Skipping invalid entry with ID: \(entry)")
                }
            } catch {
                print("Failed to replay entry: \(error)")
            }
        }
    }

    private func sanitizeForReplay(_ item: Item) -> Item? {
        guard case let .message(message) = item else { return item }

        var validContent: [Item.Message.Content] = []

        for content in message.content {
            switch content {
            case let .text(text):
                if !text.isEmpty {
                    validContent.append(.text(text))
                }
            case let .inputText(text):
                if !text.isEmpty {
                    validContent.append(.inputText(text))
                }
            case let .audio(audio):
                if let _ = audio.audio {
                    // If we have audio bytes, keep it as audio
                    validContent.append(.audio(audio))
                } else if let transcript = audio.transcript, !transcript.isEmpty {
                    // If we don't have audio bytes but have a transcript, convert to output_text
                    // Assistant messages should use output_text when they are text-only
                     validContent.append(.outputText(transcript))
                }
            case let .outputText(text):
                 if !text.isEmpty {
                    validContent.append(.outputText(text))
                }
            case let .inputAudio(audio):
                if let _ = audio.audio {
                    validContent.append(.inputAudio(audio))
                } else if let transcript = audio.transcript, !transcript.isEmpty {
                    // Convert input audio without bytes to input text
                    validContent.append(.inputText(transcript))
                }
            }
        }

        guard !validContent.isEmpty else { return nil }

        return .message(Item.Message(
            id: message.id,
            status: .completed, // Always mark replayed items as completed
            role: message.role,
            content: validContent
        ))
    }
    
    private func sendRecipe() async {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(recipe)
            if let jsonString = String(data: data, encoding: .utf8) {
                try conversation.send(from: .user, text: jsonString)
                print("Sent recipe to model")
            }
        } catch {
            print("Failed to encode recipe: \(error)")
        }
    }
    
    private func sendSystemInstruction() async {
        let systemInstruction = """
        You are a helpful sous-chef working as an assistant to a chef.

        Start by speaking 'yes chef!' only once and wait for a question. After the initial greeting, do not say 'yes chef' ever again.
        
        Only give instructions when asked. Be as incremental and step by step as possible.

        Make answers as consice as possible without missing any information. You should be concise, direct, and to the point. You MUST answer concisely with fewer than 4 lines (not including tool use), unless user asks for detail. IMPORTANT: You should minimize output tokens as much as possible while maintaining helpfulness, quality, and accuracy. Only address the specific query or task at hand, avoiding tangential information unless absolutely critical for completing the request. If you can answer in 1 sentence, please do. IMPORTANT: You should NOT answer with unnecessary preamble or postamble, unless the user asks you to.

        When an ingredient lists alternative units of measure and quantities (e.g., ounces or grams), say "or" to connect each option.

        Respond with at most one ingredient at a time, then wait until asked for more.

        If an instruction includes a specific cooking duration, and in no other circumstance, offer to set a timer.

        Stay on the topic of cooking and recipes, do not speak about other topics.
        """
        do {
            try conversation.updateSession { session in
                session.instructions = systemInstruction
            }
            print("Session updated with instructions")
        } catch {
            print("Failed to set session: \(error)")
        }
    }

    private func fetchToken() async -> String? {
        guard let url = URL(string: "https://yes-chef.ai/api/auth/openai-token") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response: \(response) data: \(data)")
                return nil
            }
            guard httpResponse.statusCode == 200 else {
                print("Invalid response status: \(httpResponse)")
                return nil
            }
            
            struct TokenResponse: Decodable {
                let value: String
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            print("Fetched token: \(tokenResponse.value)")
            return tokenResponse.value
        } catch {
            print("Error fetching token: \(error)")
            return nil
        }
    }
}
