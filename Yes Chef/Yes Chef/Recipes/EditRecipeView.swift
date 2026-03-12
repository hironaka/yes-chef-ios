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
    @Environment(\.modelContext) private var modelContext
    let recipe: Recipe?
    
    @State private var name: String
    @State private var ingredients: [String]
    @State private var instructions: [RecipeInstructionSection]
    
    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        _name = State(initialValue: recipe?.name ?? "")
        _ingredients = State(initialValue: recipe?.recipeIngredient ?? [])
        let extracted = recipe.map { extractInstructions(from: $0) } ?? []
        _instructions = State(initialValue: extracted.isEmpty ? [RecipeInstructionSection(name: nil, instructions: [])] : extracted)
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
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                ingredients.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        ingredients.append("")
                    }) {
                        Label("Add Ingredient", systemImage: "plus.circle.fill")
                    }
                }
                
                Section(header: Text("Instructions")) {
                    ForEach(instructions.indices, id: \.self) { sectionIndex in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                TextField("Section Name (Optional)", text: Binding(
                                    get: { instructions[sectionIndex].name ?? "" },
                                    set: { newValue in instructions[sectionIndex].name = newValue.isEmpty ? nil : newValue }
                                ))
                                .font(.headline)
                                
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    instructions.remove(at: sectionIndex)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            
                            ForEach(instructions[sectionIndex].instructions.indices, id: \.self) { instructionIndex in
                                VStack(alignment: .leading) {
                                    Text("Step \(instructionIndex + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        TextField("Step \(instructionIndex + 1)", text: Binding(
                                            get: {
                                                if sectionIndex < instructions.count && instructionIndex < instructions[sectionIndex].instructions.count {
                                                    return instructions[sectionIndex].instructions[instructionIndex]
                                                }
                                                return ""
                                            },
                                            set: { newValue in
                                                if sectionIndex < instructions.count && instructionIndex < instructions[sectionIndex].instructions.count {
                                                    instructions[sectionIndex].instructions[instructionIndex] = newValue
                                                }
                                            }
                                        ), axis: .vertical)
                                        
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            instructions[sectionIndex].instructions.remove(at: instructionIndex)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                    }
                                }
                            }
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                instructions[sectionIndex].instructions.append("")
                            }) {
                                Label("Add Step", systemImage: "plus.circle.fill")
                            }
                        }
                        .padding(.vertical, 5)
                        
                        if sectionIndex < instructions.count - 1 {
                            Divider()
                        }
                    }
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        instructions.append(RecipeInstructionSection(name: "", instructions: [""]))
                    }) {
                        Label("Add Section", systemImage: "plus.rectangle.on.rectangle")
                    }
                }
            }
            .navigationTitle(recipe == nil ? "Add Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        save()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func save() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedIngredients = ingredients.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        var newInstructions: [Instruction] = []
        for section in instructions {
            let sectionSteps = section.instructions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { HowToStep(type: "HowToStep", text: $0) }
            
            if sectionSteps.isEmpty { continue }
            
            if let name = section.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                newInstructions.append(.howToSection(HowToSection(type: "HowToSection", name: name, itemListElement: sectionSteps)))
            } else {
                newInstructions.append(contentsOf: sectionSteps.map { .howToStep($0) })
            }
        }
        
        if let recipe = recipe {
            recipe.name = cleanedName
            recipe.recipeIngredient = cleanedIngredients
            recipe.recipeInstructions = newInstructions
            modelContext.insert(recipe)
        } else {
            let newRecipe = Recipe(
                name: cleanedName,
                thumbnailUrl: nil,
                image: nil,
                recipeIngredient: cleanedIngredients,
                recipeInstructions: newInstructions
            )
            modelContext.insert(newRecipe)
        }
        
        try? modelContext.save()
    }
}
