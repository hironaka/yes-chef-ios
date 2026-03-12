//
//  Recipe.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 11/1/25.
//

import Foundation
import SwiftData
import UIKit

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
        if let instructionArray = try? container.decode([Instruction].self, forKey: .recipeInstructions) {
            recipeInstructions = instructionArray
        } else if let singleInstruction = try? container.decode(Instruction.self, forKey: .recipeInstructions) {
            recipeInstructions = [singleInstruction]
        } else {
            recipeInstructions = nil
        }
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

struct RecipeInstructionSection: Hashable {
    var name: String?
    var instructions: [String]
}

func extractInstructions(from recipeData: Recipe) -> [RecipeInstructionSection] {
    var sections: [RecipeInstructionSection] = []
    var defaultSectionInstructions: [String] = []

    for instruction in recipeData.recipeInstructions ?? [] {
        switch instruction {
        case .string(let text):
            defaultSectionInstructions.append(text.htmlToString())
        case .howToStep(let step):
            if let text = step.text {
                defaultSectionInstructions.append(text.htmlToString())
            }
        case .howToSection(let section):
            // If we have accumulated some default instructions, save them as a section first
            if !defaultSectionInstructions.isEmpty {
                sections.append(RecipeInstructionSection(name: nil, instructions: defaultSectionInstructions))
                defaultSectionInstructions = []
            }
            let steps = section.itemListElement.compactMap { $0.text?.htmlToString() }
            if !steps.isEmpty {
                sections.append(RecipeInstructionSection(name: section.name, instructions: steps))
            }
        }
    }

    if !defaultSectionInstructions.isEmpty {
        sections.append(RecipeInstructionSection(name: nil, instructions: defaultSectionInstructions))
    }

    return sections
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
    
    enum CodingKeys: String, CodingKey {
        case name, thumbnailUrl, image, recipeIngredient, recipeInstructions, recipeFound
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        
        // Handle polymorphic image (String or [String])
        if let images = try? container.decode([String].self, forKey: .image) {
            image = images
        } else if let singleImage = try? container.decode(String.self, forKey: .image) {
            image = [singleImage]
        } else {
            image = nil
        }
        
        recipeIngredient = try container.decodeIfPresent([String].self, forKey: .recipeIngredient)
        recipeInstructions = try container.decodeIfPresent([Instruction].self, forKey: .recipeInstructions)
        recipeFound = try container.decodeIfPresent(Bool.self, forKey: .recipeFound)
    }
    
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
        // Optimization: if it doesn't look like HTML, don't pay the NSAttributedString cost
        guard self.contains("<") || self.contains("&") else {
            return self
        }
        
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
        for section in instructions {
            if let name = section.name {
                output += "\(name)\n"
            }
            for (index, instruction) in section.instructions.enumerated() {
                output += "\(index + 1). \(instruction)\n"
            }
            output += "\n"
        }
    }

    return output
}
