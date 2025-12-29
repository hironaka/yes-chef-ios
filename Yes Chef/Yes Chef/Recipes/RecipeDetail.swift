//
//  RecipeDetail.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 11/2/25.
//

import SwiftUI
import SwiftData

struct RecipeDetail: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    enum SheetType: Identifiable {
        case voiceAssistant
        case edit
        case addGroceries([String])
        
        var id: String {
            switch self {
            case .voiceAssistant: return "voiceAssistant"
            case .edit: return "editRecipe"
            case .addGroceries: return "addGroceries"
            }
        }
    }
    
    @State private var activeSheet: SheetType?
    
    let recipe: Recipe
    
    @State private var displayIngredients: [String] = []
    @State private var displayInstructions: [String] = []
    @State private var showDeleteConfirmation = false
    @State private var scaleFactor: Double = 1.0
    @State private var isScaling = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                Text(recipe.name ?? "Untitled Recipe")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let imageUrl = recipe.image?.first ?? recipe.thumbnailUrl, let url = URL(string: imageUrl) {
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .scaledToFill()
                                .aspectRatio(1, contentMode: .fit)
                                .clipped()
                                .containerRelativeFrame(.horizontal)
                        } placeholder: {
                            ProgressView()
                        }
                        .clipped()
                    }
                    .clipped()
                    .aspectRatio(1, contentMode: .fit)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ingredients")
                        .font(.title2)
                        .fontWeight(.semibold)
                    ForEach(Array(displayIngredients.enumerated()), id: \.offset) { index, ingredient in
                        Text("• \(ingredient)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Instructions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    ForEach(Array(displayInstructions.enumerated()), id: \.offset) { index, instruction in
                        Text(instruction)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 5)
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            // Process these off the main view update cycle
            self.displayIngredients = recipe.recipeIngredient ?? []
            self.displayInstructions = extractInstructions(from: recipe)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    activeSheet = .voiceAssistant
                }) {
                    Image(systemName: "waveform.badge.microphone")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    // Dispatch to next runloop to avoid AttributeGraph update cycle crash
                    DispatchQueue.main.async {
                        activeSheet = .edit
                    }
                }) {
                    Image(systemName: "pencil")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    addToGroceries()
                }) {
                    Image(systemName: "cart")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        scale(to: 0.5)
                    }) { Label("0.5x", systemImage: "circle.lefthalf.filled") }
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        scale(to: 1.0)
                    }) { Label("1.0x (Original)", systemImage: "circle.fill") }
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        scale(to: 2.0)
                    }) { Label("2.0x", systemImage: "circle.circle") }
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        scale(to: 3.0)
                    }) { Label("3.0x", systemImage: "seal") }
                } label: {
                    Text("\(scaleFactor, specifier: "%g")x")
                        .fontWeight(.bold)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit:
                EditRecipeView(recipe: recipe)

            case .voiceAssistant:
                // Create a transient recipe with currently displayed ingredients
                let voiceRecipe = Recipe(
                    name: recipe.name,
                    thumbnailUrl: recipe.thumbnailUrl,
                    image: recipe.image,
                    recipeIngredient: displayIngredients,
                    recipeInstructions: recipe.recipeInstructions
                )
                RecipeVoiceAssistant(recipe: voiceRecipe)
                    .presentationDetents([.height(80)])
                    .presentationBackgroundInteraction(.enabled)
            case .addGroceries(let ingredients):
                AddGroceriesView(
                    groceries: ingredients,
                    onAdd: { selectedItems in
                        saveGroceries(selectedItems)
                        activeSheet = nil
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
            }
        }
        .alert("Delete Recipe?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                delete()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func delete() {
        withAnimation {
            modelContext.delete(recipe)
            dismiss()
        }
    }
    
    private func addToGroceries() {
        guard let ingredients = recipe.recipeIngredient else { return }
        let cleanIngredients = ingredients.map { $0.htmlToString() }
        activeSheet = .addGroceries(cleanIngredients)
    }
    
    private func saveGroceries(_ items: [String]) {
        for item in items {
            let newItem = GroceryItem(name: item)
            modelContext.insert(newItem)
        }
    }


    private func scale(to factor: Double) {
        guard factor != scaleFactor else { return }
        
        // Optimistic UI update if reverting to original
        if factor == 1.0 {
            self.scaleFactor = 1.0
            self.displayIngredients = recipe.recipeIngredient ?? []
            return
        }
        
        self.isScaling = true
        let originalIngredients = recipe.recipeIngredient ?? []
        
        Task {
            do {
                let scaled = try await RecipeService.shared.scaleRecipe(ingredients: originalIngredients, scaleFactor: factor)
                await MainActor.run {
                    self.displayIngredients = scaled
                    self.scaleFactor = factor
                    self.isScaling = false
                }
            } catch {
                print("Scaling failed: \(error)")
                await MainActor.run {
                    self.isScaling = false
                    // Optionally show error toast
                }
            }
        }
    }
}


#if DEBUG
struct RecipeDetail_Previews: PreviewProvider {
    static var previews: some View {
        RecipeDetail(recipe: Recipe(
            name: "Classic Tomato Bruschetta",
            thumbnailUrl: "https://static01.nyt.com/images/2021/03/14/dining/lh-cheesy-beans-and-greens/lh-cheesy-beans-and-greens-videoSixteenByNineJumbo1600-v2.jpg",
            image: ["https://static01.nyt.com/images/2021/03/14/dining/lh-cheesy-beans-and-greens/lh-cheesy-beans-and-greens-videoSixteenByNineJumbo1600-v2.jpg"],
            recipeIngredient: [
                "1 loaf French bread, cut into 1/2-inch slices",
                "1/4 cup olive oil",
                "2 cloves garlic, minced",
                "4 ripe tomatoes, diced",
                "1/4 cup chopped fresh basil",
                "1 tablespoon balsamic vinegar",
                "Salt and pepper to taste"
            ],
            recipeInstructions: [
                .string("Preheat oven to 350°F (175°C)."),
                .string("Arrange bread slices on a baking sheet. Brush with olive oil and sprinkle with garlic."),
                .string("Bake for 10-12 minutes, or until golden brown."),
                .string("In a medium bowl, combine tomatoes, basil, and balsamic vinegar. Season with salt and pepper."),
                .string("Top toasted bread with tomato mixture and serve immediately.")
            ]
        ))
    }
}
#endif
