//
//  RecipeList.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 10/25/25.
//

import SwiftUI
import SwiftData

struct RecipeList: View {
    @Query private var recipes: [Recipe]

    var body: some View {
        NavigationStack {
            List(recipes) { recipe in
                NavigationLink(destination: RecipeDetail(recipe: recipe)) {
                    HStack {
                        if let imageUrl = recipe.thumbnailUrl ?? recipe.image?.first, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                        }
                        Text(recipe.name ?? "Untitled Recipe")
                    }
                }
            }
            .navigationTitle("Recipes")
        }
    }
}

#Preview {
    RecipeList()
}
