import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            
            Search()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            Recipes()
                .tabItem {
                    Label("Recipes", systemImage: "list.bullet")
                }
            
            Meals()
                .tabItem {
                    Label("Meals", systemImage: "fork.knife")
                }
            
            Groceries()
                .tabItem {
                    Label("Groceries", systemImage: "cart")
                }
            
            Settings()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
        .background(Color(hex: "#fafafa").ignoresSafeArea())
        .onAppear {
            UITabBar.appearance().backgroundColor = UIColor(Color(hex: "#fafafa"))
        }
    }
}

#Preview {
    ContentView()
}
