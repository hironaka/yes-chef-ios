//
//  Recipe.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 11/1/25.
//

import Foundation
import SwiftData

// MARK: - Recipe Data Structures

@Model
class Recipe: Codable {
    var name: String?
    var recipeIngredient: [String]
    var recipeInstructions: [Instruction]

    enum CodingKeys: String, CodingKey {
        case name, source, thumbnailUrl, recipeIngredient, recipeInstructions
    }

    init(name: String, recipeIngredient: [String], recipeInstructions: [Instruction]) {
        self.name = name
        self.recipeIngredient = recipeIngredient
        self.recipeInstructions = recipeInstructions
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        recipeIngredient = try container.decode([String].self, forKey: .recipeIngredient)
        recipeInstructions = try container.decode([Instruction].self, forKey: .recipeInstructions)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(recipeIngredient, forKey: .recipeIngredient)
        try container.encode(recipeInstructions, forKey: .recipeInstructions)
    }
}

enum Instruction: Codable {
    case string(String)
    case howToSection(HowToSection)
    case howToStep(HowToStep)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        if let x = try? container.decode(HowToSection.self) {
            self = .howToSection(x)
            return
        }
        if let x = try? container.decode(HowToStep.self) {
            self = .howToStep(x)
            return
        }
        throw DecodingError.typeMismatch(Instruction.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Instruction"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let x):
            try container.encode(x)
        case .howToSection(let x):
            try container.encode(x)
        case .howToStep(let x):
            try container.encode(x)
        }
    }
}

struct HowToSection: Codable {
    let type: String?
    let name: String?
    let itemListElement: [HowToStep]

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case name, itemListElement
    }
}

struct HowToStep: Codable {
    let type: String?
    let text: String?

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case text
    }
}

// MARK: - Recipe Processing

func extractInstructions(from recipeData: Recipe) -> [String] {
    return recipeData.recipeInstructions.flatMap { instruction -> [String] in
        switch instruction {
        case .string(let text):
            return [text]
        case .howToSection(let section):
            if section.name == "Recipe Instructions" {
                return section.itemListElement.map { $0.text ?? "" }
            }
            return []
        case .howToStep(let step):
            return [step.text ?? ""]
        }
    }
}

func extractIngredients(from recipeData: Recipe) -> [String] {
    return recipeData.recipeIngredient
}

func convertRecipeToPlainText(from data: Data) -> String {
    let decoder = JSONDecoder()
    guard let recipe = try? decoder.decode(Recipe.self, from: data) else {
        return ""
    }

    let title = recipe.name ?? "Untitled Recipe"
    let ingredients = extractIngredients(from: recipe)
    let instructions = extractInstructions(from: recipe)

    var output = title + "\n\n"

    if !ingredients.isEmpty {
        output += "Ingredients:\n"
        for (index, ingredient) in ingredients.enumerated() {
            output += "\(index + 1). \(ingredient)\n"
        }
        output += "\n"
    }

    if !instructions.isEmpty {
        output += "Instructions:\n"
        for (index, instruction) in instructions.enumerated() {
            output += "\(index + 1). \(instruction)\n"
        }
    }

    return output
}
