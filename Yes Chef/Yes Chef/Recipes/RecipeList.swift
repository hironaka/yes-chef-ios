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
    @Environment(\.modelContext) private var modelContext
    
    enum SheetType: Identifiable {
        case manualAdd
        case imagePicker
        case extractedResult(Recipe)
        
        var id: String {
            switch self {
            case .manualAdd: return "manualAdd"
            case .imagePicker: return "imagePicker"
            case .extractedResult: return "extractedResult"
            }
        }
    }
    
    @State private var activeSheet: SheetType?
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var isExtracting = false
    @State private var showErrorAlert = false
    @State private var searchText = ""

    var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipes
        }
        
        let lowercasedSearchText = searchText.localizedLowercase
        
        return recipes.filter { recipe in
            if let name = recipe.name, name.localizedLowercase.contains(lowercasedSearchText) {
                return true
            }
            
            let ingredients = extractIngredients(from: recipe)
            if ingredients.contains(where: { $0.localizedLowercase.contains(lowercasedSearchText) }) {
                return true
            }
            
            let instructions = extractInstructions(from: recipe).flatMap { $0.instructions }
            if instructions.contains(where: { $0.localizedLowercase.contains(lowercasedSearchText) }) {
                return true
            }
            
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List(filteredRecipes) { recipe in
                    NavigationLink(value: recipe) {
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
                .navigationDestination(for: Recipe.self) { recipe in
                    RecipeDetail(recipe: recipe)
                }
                .navigationTitle("Recipes")
                .searchable(text: $searchText, prompt: "Search")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                activeSheet = .manualAdd
                            }) {
                                Label("Manual Entry", systemImage: "square.and.pencil")
                            }
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showCamera = true
                            }) {
                                Label("Camera", systemImage: "camera")
                            }
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                activeSheet = .imagePicker
                            }) {
                                Label("Photo", systemImage: "photo")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .manualAdd:
                        EditRecipeView()
                    case .imagePicker:
                        ImagePicker(image: $selectedImage)
                    case .extractedResult(let recipe):
                        EditRecipeView(recipe: recipe)
                    }
                }
                .fullScreenCover(isPresented: $showCamera) {
                    CameraPicker(image: $selectedImage)
                        .ignoresSafeArea()
                }
                .onChange(of: selectedImage) {
                    if let image = selectedImage {
                        extractRecipe(from: image)
                    }
                }
                
                if isExtracting {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Processing...")
                            .foregroundColor(.white)
                            .padding(.top, 10)
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(15)
                }


            }
        }
        .alert("Image Processing Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to extract a recipe from the image")
        }
    }
    
    private func extractRecipe(from image: UIImage) {
        isExtracting = true
        RecipeService.shared.extractRecipe(from: image) { recipe in
            isExtracting = false
            selectedImage = nil
            if let recipe = recipe {
                activeSheet = .extractedResult(recipe)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                showErrorAlert = true
            }
        }
    }
}

#Preview {
    RecipeList()
}
