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
    var thumbnailUrl: String?
    var image: [String]?
    var recipeIngredient: [String]?
    var recipeInstructions: [Instruction]?

    enum CodingKeys: String, CodingKey {
        case name, thumbnailUrl, image, recipeIngredient, recipeInstructions
    }

    init(name: String?, thumbnailUrl: String?, image: [String]?, recipeIngredient: [String]?, recipeInstructions: [Instruction]?) {
        self.name = name
        self.thumbnailUrl = thumbnailUrl
        self.image = image
        self.recipeIngredient = recipeIngredient
        self.recipeInstructions = recipeInstructions
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        
        if let images = try? container.decode([String].self, forKey: .image) {
            image = images
        } else if let imageObjects = try? container.decode([ImageObject].self, forKey: .image) {
            image = imageObjects.compactMap { $0.url ?? $0.contentUrl }
        } else if let singleImage = try? container.decode(String.self, forKey: .image) {
            image = [singleImage]
        } else if let singleImageObject = try? container.decode(ImageObject.self, forKey: .image) {
            if let url = singleImageObject.url ?? singleImageObject.contentUrl {
                image = [url]
            } else {
                image = nil
            }
        } else {
            image = nil
        }
        
        recipeIngredient = try container.decodeIfPresent([String].self, forKey: .recipeIngredient)
        recipeInstructions = try container.decodeIfPresent([Instruction].self, forKey: .recipeInstructions)
    }

    private struct ImageObject: Codable {
        let url: String?
        let contentUrl: String?
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encode(image, forKey: .image)
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
    return recipeData.recipeInstructions?.flatMap { instruction -> [String] in
        switch instruction {
        case .string(let text):
            return [text.htmlToString()]
        case .howToSection(let section):
            if section.name == "Recipe Instructions" {
                return section.itemListElement.map { $0.text?.htmlToString() ?? "" }
            }
            return []
        case .howToStep(let step):
            return [step.text?.htmlToString() ?? ""]
        }
    } ?? []
}

func extractIngredients(from recipeData: Recipe) -> [String] {
    return recipeData.recipeIngredient?.map { $0.htmlToString() } ?? []
}

struct APIRecipeResponse: Codable {
    let name: String?
    let thumbnailUrl: String?
    let image: [String]?
    let recipeIngredient: [String]?
    let recipeInstructions: [Instruction]?
    let recipeFound: Bool?
    
    // Convert this to a Recipe object if found
    func toRecipe() -> Recipe? {
        if recipeFound == false { return nil }
        return Recipe(
            name: name,
            thumbnailUrl: thumbnailUrl,
            image: image,
            recipeIngredient: recipeIngredient,
            recipeInstructions: recipeInstructions
        )
    }
}

extension String {
    func htmlToString() -> String {
        guard let data = self.data(using: .utf8) else {
            return self
        }
        do {
            let attributedString = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
            return attributedString.string
        } catch {
            return self
        }
    }
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
