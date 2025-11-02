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
    @Environment(\.presentationMode) private var presentationMode
    
    let recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let imageUrl = recipe.image?.first ?? recipe.thumbnailUrl, let url = URL(string: imageUrl) {
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(height: 300)
                        .clipped()
                        
                        Text(recipe.name ?? "Untitled Recipe")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding()
                            .background(.thinMaterial)
                            .cornerRadius(10)
                            .padding()
                    }
                } else {
                    Text(recipe.name ?? "Untitled Recipe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ingredients")
                        .font(.title2)
                        .fontWeight(.semibold)
                    ForEach(recipe.recipeIngredient, id: \.self) { ingredient in
                        Text("• \(ingredient)")
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Instructions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    ForEach(extractInstructions(from: recipe), id: \.self) { instruction in
                        Text(instruction)
                            .padding(.bottom, 5)
                    }
                }
                .padding(.horizontal)
            }
        }
        .if(recipe.image?.first != nil || recipe.thumbnailUrl != nil) { view in
            view.ignoresSafeArea(.all, edges: .top)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: delete) {
                    Image(systemName: "trash")
                }
            }
        }
    }
    
    private func delete() {
        withAnimation {
            modelContext.delete(recipe)
            presentationMode.wrappedValue.dismiss()
        }
    }
}


#if DEBUG
struct RecipeDetail_Previews: PreviewProvider {
    static var previews: some View {
        RecipeDetail(recipe: Recipe(
            name: "Classic Tomato Bruschetta",
            thumbnailUrl: "https://www.thechunkychef.com/wp-content/uploads/2018/02/Ultimate-Creamy-Baked-Mac-and-Cheese-feat.jpg",
            image: ["https://www.thechunkychef.com/wp-content/uploads/2018/02/Ultimate-Creamy-Baked-Mac-and-Cheese-feat.jpg"],
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
