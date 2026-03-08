import SwiftUI

struct HomeView: View {
    private enum FeedMode: String, CaseIterable, Identifiable {
        case personalized = "Personalized"
        case trending = "Trending"
        
        var id: String { rawValue }
    }
    
    @State private var videos: [VideoItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isFetchingMore = false
    @State private var selectedVideo: VideoItem?
    @State private var feedMode: FeedMode = .trending
    @State private var isLoggedIn = BilibiliApiService.shared.isLoggedIn
    
    // Debug state to show the link on screen
    @State private var debugVideoLink: String = ""
    
    let columns = [
        GridItem(.flexible(), spacing: 40),
        GridItem(.flexible(), spacing: 40),
        GridItem(.flexible(), spacing: 40),
        GridItem(.flexible(), spacing: 40)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                // Debug Dashboard
                HStack {
                    Text("Total Videos: \(videos.count)")
                        .font(.caption)
                        .padding()
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(10)
                    
                    Button("FETCH 1ST VIDEO LINK") {
                        fetchDebugLink()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 60)
                
                HStack {
                    Picker("Feed", selection: $feedMode) {
                        ForEach(FeedMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 600)
                    
                    if feedMode == .personalized && !isLoggedIn {
                        Text("Login required for personalized feed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 60)
                
                if !debugVideoLink.isEmpty {
                    Text("🔗 Link: \(debugVideoLink)")
                        .font(.caption)
                        .padding(.horizontal, 60)
                        .foregroundColor(.green)
                }
                
                if isLoading && videos.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Fetching Home Feed...")
                        Spacer()
                    }
                    .frame(height: 500)
                } else if let error = errorMessage, videos.isEmpty {
                    VStack {
                        Text("Error: \(error)")
                        Button("Retry Load") { loadData() }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: columns, spacing: 80) {
                        ForEach(videos) { video in
                            Button {
                                selectedVideo = video
                            } label: {
                                VideoCard(video: video)
                                    .overlay(
                                        Text("AID: \(video.videoAid ?? 0)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.5))
                                            .padding(8),
                                        alignment: .topTrailing
                                    )
                            }
                            .buttonStyle(.card)
                            .onAppear {
                                if video.id == videos.last?.id {
                                    loadMore()
                                }
                            }
                        }
                        
                        if !videos.isEmpty {
                            Button("Load More Items") {
                                loadMore()
                            }
                            .buttonStyle(.card)
                            .frame(height: 225)
                        }
                    }
                    .padding(60)
                }
            }
        }
        .onAppear {
            isLoggedIn = BilibiliApiService.shared.isLoggedIn
            if videos.isEmpty { loadData() }
        }
        .navigationTitle("Trending")
        .navigationDestination(item: $selectedVideo) { video in
            VideoDetailView(video: video)
        }
        .onChange(of: feedMode) { _, _ in
            loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: BilibiliApiService.authDidChangeNotification)) { _ in
            isLoggedIn = BilibiliApiService.shared.isLoggedIn
            loadData()
        }
    }
    
    private func loadData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                if feedMode == .personalized {
                    guard BilibiliApiService.shared.isLoggedIn else {
                        videos = []
                        errorMessage = "Please log in to view personalized videos."
                        isLoading = false
                        return
                    }
                    videos = try await BilibiliApiService.shared.fetchPersonalizedFeed()
                } else {
                    videos = try await BilibiliApiService.shared.fetchTrending()
                }
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func loadMore() {
        guard !isLoading, !isFetchingMore else { return }
        isFetchingMore = true
        
        Task {
            do {
                let more: [VideoItem]
                if feedMode == .personalized {
                    // For personalized feed, we can use a simple counter or let the API handle fresh_idx
                    // Bilibili's recommended feed often uses fresh_idx as a simple increment or session-based index
                    let nextIdx = (videos.count / 20) + 1
                    more = try await BilibiliApiService.shared.fetchPersonalizedFeed(idx: nextIdx)
                } else {
                    guard let lastIdx = videos.last?.idx else { 
                        isFetchingMore = false
                        return 
                    }
                    more = try await BilibiliApiService.shared.fetchTrending(idx: lastIdx)
                }
                
                await MainActor.run {
                    // Filter out duplicates based on id
                    let currentIds = Set(videos.map { $0.id })
                    let uniqueMore = more.filter { !currentIds.contains($0.id) }
                    
                    if uniqueMore.isEmpty && !more.isEmpty {
                        print("⚠️ [HOME] Fetched more items but all were duplicates.")
                    }
                    
                    videos.append(contentsOf: uniqueMore)
                    isFetchingMore = false
                }
            } catch {
                print("❌ [HOME] Load more failed: \(error.localizedDescription)")
                await MainActor.run {
                    isFetchingMore = false
                }
            }
        }
    }
    
    // Debug helper to extract the actual video playback URL
    private func fetchDebugLink() {
        guard let firstVideo = videos.first else {
            self.debugVideoLink = "No video available"
            return
        }
        let bvid = firstVideo.videoBvid
        let aid = bvid == nil ? firstVideo.videoAid : nil
        if bvid == nil && aid == nil {
            self.debugVideoLink = "No AID/BVID available"
            return
        }
        self.debugVideoLink = "Fetching details for AID \(aid ?? -1), BVID \(bvid ?? "nil")..."
        
        Task {
            do {
                let detail = try await BilibiliApiService.shared.fetchVideoDetail(aid: aid, bvid: bvid)
                guard let cid = detail.cid else {
                    self.debugVideoLink = "Missing CID in details"
                    return
                }
                
                let resolvedAid = detail.aid ?? aid
                guard let playAid = resolvedAid else {
                    self.debugVideoLink = "Missing AID for play URL"
                    return
                }
                self.debugVideoLink = "Fetching Play URL (aid: \(playAid), cid: \(cid))..."
                let playUrlResp = try await BilibiliApiService.shared.fetchPlayUrl(aid: playAid, cid: cid)
                
                if let url = playUrlResp.durl?.first?.url {
                    self.debugVideoLink = url.httpsUrl
                    print("✅ Debug Video Link: \(url.httpsUrl)")
                } else {
                    self.debugVideoLink = "No URL found in play response"
                }
                
            } catch {
                self.debugVideoLink = "Error: \(error.localizedDescription)"
            }
        }
    }
}
