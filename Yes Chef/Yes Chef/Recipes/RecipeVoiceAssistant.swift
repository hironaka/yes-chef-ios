import SwiftUI
import RealtimeAPI

struct RecipeVoiceAssistant: View {
    @State private var conversation = Conversation()
    @StateObject private var audioMonitor = AudioLevelMonitor()
    let recipe: Recipe

    var body: some View {
        VStack(spacing: 20) {
            Waveform(level: audioMonitor.level)
                .frame(height: 60)
        }
        .task {
            do {
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
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            audioMonitor.stopMonitoring()
            // conversation.disconnect() // Assuming we might want to disconnect
        }
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
