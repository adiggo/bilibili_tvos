import SwiftUI

struct CategoriesView: View {
    let categories = [
        Category(id: 1, name: "Anime", icon: "tv"),
        Category(id: 3, name: "Entertainment", icon: "theatermasks"),
        Category(id: 4, name: "Games", icon: "gamecontroller"),
        Category(id: 5, name: "Technology", icon: "cpu"),
        Category(id: 36, name: "Science", icon: "flask"),
        Category(id: 160, name: "Life", icon: "house"),
        Category(id: 119, name: "Music", icon: "music.note"),
        Category(id: 155, name: "Fashion", icon: "tshirt")
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 40) {
                ForEach(categories) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        VStack {
                            Image(systemName: category.icon)
                                .font(.system(size: 100))
                                .padding()
                            Text(category.name)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(20)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(40)
        }
        .navigationTitle("Categories")
    }
}

struct Category: Identifiable {
    let id: Int
    let name: String
    let icon: String
}

struct CategoryDetailView: View {
    let category: Category
    @State private var videos: [VideoItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedVideo: VideoItem?
    @Environment(\.dismiss) private var dismiss
    
    let columns = [
        GridItem(.flexible(), spacing: 40),
        GridItem(.flexible(), spacing: 40),
        GridItem(.flexible(), spacing: 40),
        GridItem(.flexible(), spacing: 40)
    ]
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading \(category.name)...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                Text("Error: \(error)")
            } else {
                LazyVGrid(columns: columns, spacing: 60) {
                    ForEach(videos) { video in
                        Button {
                            selectedVideo = video
                        } label: {
                            VideoCard(video: video)
                        }
                        .buttonStyle(.card)
                    }
                }
                .drawingGroup()
                .padding(40)
            }
        }
        .navigationTitle(category.name)
        .onAppear {
            loadCategoryVideos()
        }
        .navigationDestination(item: $selectedVideo) { video in
            VideoDetailView(video: video)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
    }
    
    private func loadCategoryVideos() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                videos = try await BilibiliApiService.shared.fetchCategoryVideos(rid: category.id)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
