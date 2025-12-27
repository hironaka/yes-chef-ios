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
    @State private var selectedImage: UIImage?
    @State private var isExtracting = false
    @State private var showingErrorToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                List(recipes) { recipe in
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
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: {
                                activeSheet = .manualAdd
                            }) {
                                Label("Manual Entry", systemImage: "square.and.pencil")
                            }
                            
                            Button(action: {
                                activeSheet = .imagePicker
                            }) {
                                Label("From Photo", systemImage: "photo")
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
                        Text("Extracting recipe...")
                            .foregroundColor(.white)
                            .padding(.top, 10)
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(15)
                }

                if showingErrorToast {
                    VStack {
                        Spacer()
                        ToastView(
                            toastType: .error,
                            title: "Extraction Failed",
                            subtitle: "Could not extract recipe from the photo.",
                            onUndo: {
                                withAnimation {
                                    showingErrorToast = false
                                }
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 50)
                    }
                }
            }
        }
    }
    
    private func extractRecipe(from image: UIImage) {
        isExtracting = true
        RecipeExtractor.shared.extractRecipe(from: image) { recipe in
            isExtracting = false
            selectedImage = nil
            if let recipe = recipe {
                activeSheet = .extractedResult(recipe)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation {
                    showingErrorToast = true
                }
            }
        }
    }
}

#Preview {
    RecipeList()
}
