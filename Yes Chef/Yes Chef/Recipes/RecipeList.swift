//
//  RecipeList.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 10/25/25.
//

import SwiftUI
import SwiftData

struct RecipeList: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    var body: some View {
        NavigationStack {
            List(recipes) { recipe in
                NavigationLink(destination: RecipeDetail(recipe: recipe)) {
                    HStack {
                        Text(recipe.name ?? "Untitled Recipe")
                            .lineLimit(2)
                        
                        Spacer()
                        
                        if let imageUrl = recipe.thumbnailUrl ?? recipe.image?.first, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .clipped()
                        } else {
                            // Empty frame to maintain consistent spacing even without image
                            Color.clear.frame(width: 50, height: 50)
                        }
                    }
                    .frame(height: 50)
                }
            }
            .navigationTitle("Recipes")
        }
    }
}

#Preview {
    RecipeList()
}
