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
    @State private var isVoiceAssistantPresented = false
    
    let recipe: Recipe

    var body: some View {
        ScrollView {
        
            VStack(alignment: .leading, spacing: 20) {
                Text(recipe.name ?? "Untitled Recipe")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
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
                    .overlay(alignment: .center) {
                        if isVoiceAssistantPresented {
                            RecipeVoiceAssistant(recipe: recipe)
                                .padding()
                                .cornerRadius(20)
                                .shadow(radius: 10)
                                .padding()
                        }
                    }
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        isVoiceAssistantPresented.toggle()
                        print("Mic button tapped. New state: \(isVoiceAssistantPresented)")
                    }) {
                        if isVoiceAssistantPresented {
                            Text("end")
                                .foregroundStyle(.red)
                        } else {
                            Image(systemName: "waveform.badge.microphone")
                        }
                    }
                    
                    Button(action: delete) {
                        Image(systemName: "trash")
                    }
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
