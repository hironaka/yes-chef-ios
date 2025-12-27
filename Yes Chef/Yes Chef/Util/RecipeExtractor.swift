//
//  RecipeExtractor.swift
//  Yes Chef
//
//  Created by Antigravity on 12/27/25.
//

import Foundation
import UIKit

class RecipeExtractor {
    static let shared = RecipeExtractor()
    private let apiUrl = URL(string: "https://yes-chef.ai/api/recipe/extract")!
    
    func extractRecipe(from image: UIImage, completion: @escaping (Recipe?) -> Void) {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to get JPEG data from image")
            completion(nil)
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        let imageContent = "data:image/jpeg;base64,\(base64Image)"
        
        var request = URLRequest(url: apiUrl)
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
}
