//
//  RecipeService.swift
//  Yes Chef
//
//  Created by Antigravity on 12/27/25.
//

import Foundation
import UIKit

struct ScaleResponse: Decodable {
    let scaledIngredients: [String]
}

class RecipeService {
    static let shared = RecipeService()
    private let extractUrl = URL(string: "https://yes-chef.ai/api/recipe/extract")!
    private let scaleUrl = URL(string: "https://yes-chef.ai/api/recipe/scale")!
    
    func extractRecipe(from image: UIImage, completion: @escaping (Recipe?) -> Void) {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to get JPEG data from image")
            completion(nil)
            return
        }
        

        let base64Image = imageData.base64EncodedString()
        // Structure matches Google Vertex AI 'Part' object for inline data
        let imageContent: [String: Any] = [
            "inlineData": [
                "data": base64Image,
                "mimeType": "image/jpeg"
            ]
        ]
        
        var request = URLRequest(url: extractUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["imageContent": imageContent]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Extraction API request failed: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data else {
                print("Extraction API returned no data")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(APIRecipeResponse.self, from: data)
                if let recipe = response.toRecipe() {
                    DispatchQueue.main.async { completion(recipe) }
                } else {
                    print("Extraction API returned no recipe found")
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Failed to decode extraction API response: \(error)\nResponse: \(jsonString)")
                } else {
                    print("Failed to decode extraction API response: \(error)")
                }
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
    
    func scaleRecipe(ingredients: [String], scaleFactor: Double) async throws -> [String] {
        var request = URLRequest(url: scaleUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "ingredients": ingredients,
            "scaleFactor": scaleFactor
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(ScaleResponse.self, from: data)
        return decodedResponse.scaledIngredients
    }
}
