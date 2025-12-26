import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Search()
                .tabItem {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .tag(0)
            
            RecipeList()
                .tabItem {
                    Label("Recipes", systemImage: "list.bullet")
                }
                .tag(1)
        }
        .onChange(of: selectedTab) {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

#Preview {
    ContentView()
}
