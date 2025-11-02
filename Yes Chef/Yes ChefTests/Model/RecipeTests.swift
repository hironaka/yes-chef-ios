//
//  RecipeTests.swift
//  Yes ChefTests
//
//  Created by Hannah Hironaka on 11/2/25.
//

import Foundation
import Testing
@testable import Yes_Chef

class RecipeTests {

    func loadTestData(from file: String) throws -> Data {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: file, withExtension: "json") else {
            throw TestError.fileNotFound
        }
        return try Data(contentsOf: url)
    }

    @Test func testRecipeDecoding() async throws {
        let data = try loadTestData(from: "mac_and_cheese")
        let decoder = JSONDecoder()
        let recipe = try decoder.decode(Recipe.self, from: data)

        #expect(recipe.name == "Creamy Homemade Baked Mac and Cheese")
        #expect(recipe.recipeIngredient.count == 10)
        #expect(recipe.recipeInstructions.count == 8)
    }

    @Test func testPlainTextConversion() async throws {
        let data = try loadTestData(from: "mac_and_cheese")
        let plainText = convertRecipeToPlainText(from: data)

        #expect(plainText.contains("Creamy Homemade Baked Mac and Cheese"))
        #expect(plainText.contains("Ingredients:"))
        #expect(plainText.contains("Instructions:"))
        #expect(plainText.contains("1. 1 lb. dried elbow pasta"))
        #expect(plainText.contains("8. Sprinkle the top with the last 1 1/2 cups of cheese and bake for 15 minutes, until cheesy is bubbly and lightly golden brown."))
    }
}

enum TestError: Error {
    case fileNotFound
}
