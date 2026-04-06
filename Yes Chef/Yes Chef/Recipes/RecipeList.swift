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
    @Binding var selectedTab: Int
    @Binding var urlToLoad: URL?

    enum SheetType: Identifiable {
        case manualAdd
        case imagePicker
        case filePicker
        case extractedResult(Recipe)

        var id: String {
            switch self {
            case .manualAdd: return "manualAdd"
            case .imagePicker: return "imagePicker"
            case .filePicker: return "filePicker"
            case .extractedResult: return "extractedResult"
            }
        }
    }

    @State private var activeSheet: SheetType?
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var selectedFileData: Data?
    @State private var selectedFileMimeType: String?
    @State private var isExtracting = false
    @State private var showErrorAlert = false
    @State private var showURLAlert = false
    @State private var inputURL = ""
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
                                Label("Photo Library", systemImage: "photo")
                            }

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                activeSheet = .filePicker
                            }) {
                                Label("Files", systemImage: "doc")
                            }

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                inputURL = ""
                                showURLAlert = true
                            }) {
                                Label("URL", systemImage: "link")
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
                    case .filePicker:
                        FilePicker(fileData: $selectedFileData, mimeType: $selectedFileMimeType)
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
                .onChange(of: selectedFileData) {
                    if let data = selectedFileData, let mime = selectedFileMimeType {
                        extractRecipeFromFile(data: data, mimeType: mime)
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
        .alert("Processing Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to extract a recipe")
        }
        .alert("Enter URL", isPresented: $showURLAlert) {
            TextField("https://...", text: $inputURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Go") { handleURL() }
            Button("Cancel", role: .cancel) { }
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

    private func handleURL() {
        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return }

        if let host = url.host?.lowercased(),
           host.contains("youtube.com") || host.contains("youtu.be") {
            isExtracting = true
            RecipeService.shared.extractRecipe(fromYouTubeURL: trimmed) { recipe in
                isExtracting = false
                if let recipe = recipe {
                    activeSheet = .extractedResult(recipe)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showErrorAlert = true
                }
            }
        } else {
            urlToLoad = url
            selectedTab = 0
        }
    }

    private func extractRecipeFromFile(data: Data, mimeType: String) {
        isExtracting = true
        RecipeService.shared.extractRecipe(fromData: data, mimeType: mimeType) { recipe in
            isExtracting = false
            selectedFileData = nil
            selectedFileMimeType = nil
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
    RecipeList(selectedTab: .constant(1), urlToLoad: .constant(nil))
}
