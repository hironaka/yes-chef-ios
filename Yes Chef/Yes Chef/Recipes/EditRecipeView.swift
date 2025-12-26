//
//  EditRecipeView.swift
//  Yes Chef
//
//  Created by Antigravity on 12/26/25.
//

import SwiftUI
import SwiftData

struct EditRecipeView: View {
    @Environment(\.dismiss) var dismiss
    let recipe: Recipe
    
    @State private var name: String
    @State private var ingredients: [String]
    @State private var instructions: [String]
    
    init(recipe: Recipe) {
        self.recipe = recipe
        _name = State(initialValue: recipe.name ?? "")
        _ingredients = State(initialValue: recipe.recipeIngredient ?? [])
        _instructions = State(initialValue: extractInstructions(from: recipe))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Recipe Name")) {
                    TextField("Name", text: $name)
                }
                
                Section(header: Text("Ingredients")) {
                    ForEach(ingredients.indices, id: \.self) { index in
                        HStack {
                            TextField("Ingredient \(index + 1)", text: $ingredients[index])
                            if ingredients.count > 0 {
                                Button(action: {
                                    ingredients.remove(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                    }
                    
                    Button(action: {
                        ingredients.append("")
                    }) {
                        Label("Add Ingredient", systemImage: "plus.circle.fill")
                    }
                }
                
                Section(header: Text("Instructions")) {
                    ForEach(instructions.indices, id: \.self) { index in
                        VStack(alignment: .leading) {
                            Text("Step \(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("Step \(index + 1)", text: $instructions[index], axis: .vertical)
                                
                                if instructions.count > 0 {
                                    Button(action: {
                                        instructions.remove(at: index)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        instructions.append("")
                    }) {
                        Label("Add Step", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func save() {
        recipe.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.recipeIngredient = ingredients.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        recipe.recipeInstructions = instructions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.map { .string($0) }
    }
}
