//
//  Recipes.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 10/25/25.
//

import SwiftUI
import SwiftData

struct Recipes: View {
    @Query private var recipes: [Recipe]

    var body: some View {
        NavigationView {
            List(recipes) { recipe in
                Text(recipe.name ?? "Untitled Recipe")
            }
            .navigationTitle("Recipes")
        }
    }
}

#Preview {
    Recipes()
}
