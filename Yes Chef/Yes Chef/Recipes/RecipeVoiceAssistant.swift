import SwiftUI
import RealtimeAPI

struct RecipeVoiceAssistant: View {
    @State private var conversation = Conversation()

    var body: some View {
        Text("Say something!")
            .task {
                do {
                    if let token = await fetchToken() {
                        try await conversation.connect(ephemeralKey: token)
                    } else {
                        print("Failed to fetch token")
                    }
                } catch {
                    print("Failed to connect: \(error)")
                }
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
