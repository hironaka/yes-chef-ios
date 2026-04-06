import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var urlToLoad: URL?

    var body: some View {
        TabView(selection: $selectedTab) {
            Search(urlToLoad: $urlToLoad)
                .tabItem {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .tag(0)

            RecipeList(selectedTab: $selectedTab, urlToLoad: $urlToLoad)
                .tabItem {
                    Label("Recipes", systemImage: "list.bullet")
                }
                .tag(1)

            Groceries()
                .tabItem {
                    Label("Groceries", systemImage: "cart")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

#Preview {
    ContentView()
}
