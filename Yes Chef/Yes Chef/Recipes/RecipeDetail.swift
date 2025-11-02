//
//  RecipeDetail.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 11/2/25.
//

import SwiftUI

struct RecipeDetail: View {
    let recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let imageUrl = recipe.image?.first ?? recipe.thumbnailUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity)
                }

                Text(recipe.name ?? "Untitled Recipe")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)

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
    }
}
