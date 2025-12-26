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
        let decoder = JSONDecoder()
        let data1 = try loadTestData(from: "mac_and_cheese")
        let recipe1 = try decoder.decode(Recipe.self, from: data1)

        #expect(recipe1.name == "Creamy Homemade Baked Mac and Cheese")
        #expect(recipe1.thumbnailUrl == "https://www.thechunkychef.com/wp-content/uploads/2018/02/Ultimate-Creamy-Baked-Mac-and-Cheese-feat.jpg")
        #expect(recipe1.recipeIngredient?.count == 10)
        #expect(recipe1.recipeInstructions?.count == 8)

        let data2 = try loadTestData(from: "lassagna")
        let recipe2 = try decoder.decode(Recipe.self, from: data2)

        #expect(recipe2.name == "Easy Homemade Lasagna")
        #expect(recipe2.image?.count == 4)
        #expect(recipe2.image?[0] == "https://www.spendwithpennies.com/wp-content/uploads/2022/12/1200-Easy-Homemade-Lasagna-SpendWithPennies.jpg")
        #expect(recipe2.recipeIngredient?.count == 14)
        #expect(recipe2.recipeInstructions?.count == 8)

        let data3 = try loadTestData(from: "braised_beans")
        let recipe3 = try decoder.decode(Recipe.self, from: data3)

        #expect(recipe3.name == "Braised White Beans and Greens With Parmesan")
        #expect(recipe3.image?.count == 4)
        #expect(recipe3.image?[0] == "https://static01.nyt.com/images/2021/03/14/dining/lh-cheesy-beans-and-greens/lh-cheesy-beans-and-greens-videoSixteenByNineJumbo1600-v2.jpg")
        #expect(recipe3.recipeIngredient?.count == 14)
        #expect(recipe3.recipeInstructions?.count == 4)
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

    @Test func testEscaping() async throws {
        let data = try loadTestData(from: "escaping_test")
        let plainText = convertRecipeToPlainText(from: data)

        #expect(plainText.contains("1. 1 cup of \"special\" water"))
        #expect(plainText.contains("2. 2 tbsp of sugar"))
        #expect(plainText.contains("1. First, mix the ingredients. Be careful."))
        #expect(plainText.contains("2. Then, bake at 350°F."))
    }
}

enum TestError: Error {
    case fileNotFound
}
