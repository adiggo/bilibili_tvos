import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var videos: [VideoItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedVideo: VideoItem?
    
    let columns = [
        GridItem(.flexible(), spacing: 40),
        GridItem(.flexible(), spacing: 40),
        GridItem(.flexible(), spacing: 40),
        GridItem(.flexible(), spacing: 40)
    ]
    
    var body: some View {
        VStack {
            TextField("Search videos...", text: $searchText)
                .padding()
                .onSubmit {
                    performSearch()
                }
            
            ScrollView {
                if isLoading {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                } else if videos.isEmpty && !searchText.isEmpty {
                    Text("No results found for '\(searchText)'")
                        .foregroundColor(.secondary)
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
                    .padding(40)
                }
            }
        }
        .navigationTitle("Search")
        .navigationDestination(item: $selectedVideo) { video in
            VideoDetailView(video: video)
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                videos = try await BilibiliApiService.shared.search(keyword: searchText)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
