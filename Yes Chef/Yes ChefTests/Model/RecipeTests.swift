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

        let data4 = try loadTestData(from: "atk_beef_stew")
        let recipe4 = try decoder.decode(Recipe.self, from: data4)
        #expect(recipe4.name == "Best Beef Stew")
        #expect(recipe4.recipeIngredient?.count == 3)
        #expect(recipe4.recipeInstructions?.count == 2)
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

    @Test func testAPIRecipeResponseDecoding() async throws {
        let decoder = JSONDecoder()
        
        // Case 1: Single string image
        let jsonStringImage = """
        {
            "name": "Single Image Recipe",
            "image": "https://example.com/image.jpg",
            "recipeIngredient": ["Ingredient 1", "Ingredient 1"],
            "recipeInstructions": ["Step 1"],
            "recipeFound": true
        }
        """
        let dataStringImage = jsonStringImage.data(using: .utf8)!
        let responseStringImage = try decoder.decode(APIRecipeResponse.self, from: dataStringImage)
        let recipeStringImage = responseStringImage.toRecipe()
        
        #expect(recipeStringImage?.image?.count == 1)
        #expect(recipeStringImage?.image?.first == "https://example.com/image.jpg")
        #expect(recipeStringImage?.recipeIngredient?.count == 2)
        #expect(recipeStringImage?.recipeIngredient?[0] == "Ingredient 1")
        #expect(recipeStringImage?.recipeIngredient?[1] == "Ingredient 1") // Verify duplicates preserved
        
        // Case 2: Array of images
        let jsonArrayImage = """
        {
            "name": "Array Image Recipe",
            "image": ["https://example.com/img1.jpg", "https://example.com/img2.jpg"],
            "recipeFound": true
        }
        """
        let dataArrayImage = jsonArrayImage.data(using: .utf8)!
        let responseArrayImage = try decoder.decode(APIRecipeResponse.self, from: dataArrayImage)
        let recipeArrayImage = responseArrayImage.toRecipe()
        
        #expect(recipeArrayImage?.image?.count == 2)
        #expect(recipeArrayImage?.image?.contains("https://example.com/img1.jpg") ?? false)
        
        // Case 3: No image
        let jsonNoImage = """
        {
            "name": "No Image Recipe",
            "recipeFound": true
        }
        """
        let dataNoImage = jsonNoImage.data(using: .utf8)!
        let responseNoImage = try decoder.decode(APIRecipeResponse.self, from: dataNoImage)
        let recipeNoImage = responseNoImage.toRecipe()
        
        #expect(recipeNoImage?.image == nil)
    }
}

enum TestError: Error {
    case fileNotFound
}
