import SwiftUI

struct MainView: View {
    @State private var selectedTab = Tab.home
    
    enum Tab {
        case home, search, categories, account, settings
    }
    
    var body: some View {
        // TabView MUST be the absolute root on tvOS. 
        // Wrapping TabView inside a NavigationStack breaks all click interactions.
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(Tab.home)
            
            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(Tab.search)
            
            NavigationStack {
                CategoriesView()
            }
            .tabItem {
                Label("Categories", systemImage: "list.bullet")
            }
            .tag(Tab.categories)
            
            NavigationStack {
                AccountView()
            }
            .tabItem {
                Label("Account", systemImage: "person.crop.circle")
            }
            .tag(Tab.account)
            
            NavigationStack {
                Text("Settings coming soon...")
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
        }
        .onAppear {
            if AppDebug.isEnabled {
                print("🟢 MainView appeared: \(Date().timeIntervalSince1970)")
            }
        }
    }
}
