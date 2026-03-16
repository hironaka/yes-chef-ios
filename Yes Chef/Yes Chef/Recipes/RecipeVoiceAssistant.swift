import SwiftUI
import RealtimeAPI
import AVFoundation
import LiveKitWebRTC

struct RecipeVoiceAssistant: View {
    @State private var conversation = Conversation()
    @State private var handledFunctionCalls: Set<String> = []
    @StateObject private var audioMonitor = AudioLevelMonitor()
    let recipe: Recipe
    @ObservedObject var timerState: TimerState
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Waveform(level: audioMonitor.level)
                .frame(height: 60)
                .padding(.horizontal, 60)
                
            HStack {
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
            }
        }
        .task {
            await initialConnect()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(59 * 60))
                if !Task.isCancelled {
                    await reconnect()
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            disconnect()
            audioMonitor.stopMonitoring()
        }
        .onChange(of: conversation.entries) { _, newEntries in
            Task { @MainActor in
                handleEntriesChange(entries: newEntries)
            }
        }
    }

    private func handleEntriesChange(entries: [Item]) {
        guard let lastItem = entries.last else { return }
        if case .functionCall(let call) = lastItem {
            print("Found function call \(call)")
            handleFunctionCall(call)
        }
    }
    
    private func handleFunctionCall(_ call: Item.FunctionCall) {
        print("Handle function call: \(call.name)")
        switch call.name {
        case "start_timer":
            struct Args: Codable { let duration: Int }
            guard let data = call.arguments.data(using: .utf8),
                  let args = try? JSONDecoder().decode(Args.self, from: data) else {
                return
            }
            timerState.start(duration: args.duration)
            try? conversation.send(result: .init(id: UUID().uuidString.replacingOccurrences(of: "-", with: ""), callId: call.callId, output: "Timer started for \(call.arguments) seconds."))
        case "stop_timer":
            timerState.stop()
            try? conversation.send(result: .init(id: UUID().uuidString.replacingOccurrences(of: "-", with: ""), callId: call.callId, output: "Timer stopped."))
        case "pause_timer":
            timerState.pause()
            try? conversation.send(result: .init(id: UUID().uuidString.replacingOccurrences(of: "-", with: ""), callId: call.callId, output: "Timer paused."))
        case "resume_timer":
            timerState.resume()
            try? conversation.send(result: .init(id: UUID().uuidString.replacingOccurrences(of: "-", with: ""), callId: call.callId, output: "Timer resumed."))
        default:
            break
        }
    }

    private func initialConnect() async {
        do {
            configureAudioSession()
            if let token = await fetchToken() {
                try await conversation.connect(ephemeralKey: token)
                await conversation.waitForConnection()
                
                // Start monitoring only after connection is established and session is configured by RealtimeAPI
                audioMonitor.startMonitoring()
                
                await sendSystemInstruction()
                await sendRecipe()
            } else {
                print("Failed to fetch token")
            }
        } catch {
            print("Failed to connect: \(error)")
        }
    }

    private func disconnect() {
        conversation.disconnect()
        deactiveAudioSession()
    }
    
    private func reconnect() async {
        print("[Reconnect] Attempting to reconnect...")
        let previousEntries = conversation.entries
        // Stop the old audio monitor since we're reconnecting
        audioMonitor.stopMonitoring()

        disconnect()

        conversation = Conversation()
        
        print("[Reconnect] New conversation created — muted: \(conversation.muted), status: \(conversation.status)")

        do {
            configureAudioSession()
            if let token = await fetchToken() {
                try await conversation.connect(ephemeralKey: token)
                print("[Reconnect] connect() returned, waiting for connection...")
                await conversation.waitForConnection()
                
                // Restart audio monitoring with the new connection
                audioMonitor.startMonitoring()
                
                print("Reconnected successfully, sending system instruction...")
                await sendSystemInstruction()
                await sendRecipe()

                print("[Reconnect] Replaying \(previousEntries.count) previous entries...")
                await replayConversationHistory(previousEntries)

                print("[Reconnect] Reconnection complete")
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
    
    private func configureAudioSession() {
        print("Configuring AVAudioSession")
        do {
            let audioSession = LKRTCAudioSession.sharedInstance()
            audioSession.lockForConfiguration()
            defer { audioSession.unlockForConfiguration() }
            audioSession.ignoresPreferredAttributeConfigurationErrors = true
            
            let configuration = LKRTCAudioSessionConfiguration.webRTC()
            configuration.category = AVAudioSession.Category.playAndRecord.rawValue
            configuration.mode = AVAudioSession.Mode.voiceChat.rawValue
            configuration.categoryOptions = [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
            
            try audioSession.setConfiguration(configuration, active: true)
            audioSession.isAudioEnabled = true
            audioMonitor.setupRecorder()
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }

    private func deactiveAudioSession() {
        print("Deactivating AVAudioSession")
        do {
            let audioSession = LKRTCAudioSession.sharedInstance()
            audioSession.lockForConfiguration()
            defer {
                audioSession.unlockForConfiguration()
            }
            try audioSession.setActive(false)
            audioSession.isAudioEnabled = false
        } catch {
            print("Failed to deactivate AVAudioSession: \(error)")
        }
    }

    private func replayConversationHistory(_ previousEntries: [Item]) async {
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
        
        Only give instructions when asked. Be as incremental and step by step as possible. Do not move on to the next step until you've received a clear direct request to.

        Make answers as consice as possible without missing any information. You should be concise, direct, and to the point. You MUST answer concisely with fewer than 4 lines (not including tool use), unless user asks for detail. IMPORTANT: You should minimize output tokens as much as possible while maintaining helpfulness, quality, and accuracy. Only address the specific query or task at hand, avoiding tangential information unless absolutely critical for completing the request. If you can answer in 1 sentence, please do. IMPORTANT: You should NOT answer with unnecessary preamble or postamble, unless the user asks you to.

        When an ingredient lists alternative units of measure and quantities (e.g., ounces or grams), say "or" to connect each option.

        Respond with at most one ingredient at a time, then wait until asked for more.

        If an instruction includes a specific cooking duration, and in no other circumstance, offer to set a timer.

        Stay on the topic of cooking and recipes, do not speak about other topics.
        """
        do {
            try conversation.updateSession { session in
                session.instructions = systemInstruction
                session.tools = [
                    .function(.init(
                        name: "start_timer",
                        description: "Call this function when a user asks to start or set a timer.",
                        parameters: .object(
                            properties: [
                                "duration": .integer(description: "The duration of the timer in seconds.")
                            ]
                        )
                    )),
                    .function(.init(
                        name: "stop_timer",
                        description: "Call this function when a user asks to stop (end and reset) the current timer.",
                        parameters: .object(properties: [:])
                    )),
                    .function(.init(
                        name: "pause_timer",
                        description: "Call this function when a user asks to pause the current timer.",
                        parameters: .object(properties: [:])
                    )),
                    .function(.init(
                        name: "resume_timer",
                        description: "Call this function when a user asks to resume the paused timer.",
                        parameters: .object(properties: [:])
                    ))
                ]
                session.toolChoice = .auto
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
