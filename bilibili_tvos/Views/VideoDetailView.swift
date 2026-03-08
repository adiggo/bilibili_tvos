import SwiftUI

struct VideoDetailView: View {
    let video: VideoItem
    @State private var videoDetail: VideoDetailResponse?
    @State private var bangumiDetail: BangumiDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showPlayer = false
    @State private var resolvedAid: Int?
    @State private var resolvedCid: Int?
    @State private var resolvedEpId: Int?
    @Environment(\.dismiss) private var dismiss
    
    var isBangumi: Bool { video.isBangumi }
    
    @State private var selectedEpisodeIndex: Int = 0
    @FocusState private var focusedItem: FocusElement?
    
    enum FocusElement: Hashable {
        case playButton
        case episode(Int)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 60) {
            // Left Column: Thumbnail and Play Button
            VStack(spacing: 40) {
                CachedAsyncImage(
                    urlString: video.displayCover,
                    targetSize: CGSize(width: 800, height: 450),
                    contentMode: .fit,
                    cornerRadius: 20,
                    placeholder: Rectangle().fill(Color.gray)
                )
                .frame(width: 800)
                
                VStack(spacing: 20) {
                    Button(action: {
                        print("🔘 [CLICK] PLAY BUTTON CLICKED!")
                        if resolvedAid != nil && resolvedCid != nil {
                            showPlayer = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(isBangumi ? "Play Selected Episode" : "Play Video")
                        }
                        .padding()
                    }
                    .buttonStyle(.card)
                    .focused($focusedItem, equals: .playButton)
                    .disabled(resolvedAid == nil || resolvedCid == nil)
                    
                    if isBangumi, let episodes = bangumiDetail?.episodes, episodes.count > 1 {
                        Text("Selected: \(episodes[selectedEpisodeIndex].title ?? "Episode \(selectedEpisodeIndex + 1)")")
                            .font(.headline)
                            .foregroundColor(.bilibiliPink)
                    }
                }
                
                // On-screen debug info
                Text("AID: \(resolvedAid ?? -1) | CID: \(resolvedCid ?? -1) | EP: \(resolvedEpId ?? -1)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .focusSection() // Group 1
            
            // Right Column: Meta Data and Episodes
            VStack(alignment: .leading, spacing: 20) {
                Text(video.displayTitle)
                    .font(.largeTitle)
                    .bold()
                
                HStack {
                    CachedAsyncImage(
                        urlString: video.displayFace,
                        targetSize: CGSize(width: 60, height: 60),
                        contentMode: .fill,
                        cornerRadius: 30,
                        placeholder: Circle().fill(Color.gray)
                    )
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    
                    Text(video.displayAuthor)
                        .font(.headline)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        if let detail = videoDetail {
                            Text(detail.desc ?? "No description available")
                                .font(.body)
                                .foregroundColor(.secondary)
                        } else if let bangumi = bangumiDetail {
                            Text(bangumi.evaluate ?? "No evaluation available")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            // Episode List
                            if let episodes = bangumi.episodes, !episodes.isEmpty {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("Episodes (\(episodes.count))")
                                        .font(.title3)
                                        .bold()
                                    
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 30) {
                                        ForEach(0..<episodes.count, id: \.self) { index in
                                            Button(action: {
                                                selectedEpisodeIndex = index
                                                resolvedAid = episodes[index].aid
                                                resolvedCid = episodes[index].cid
                                                resolvedEpId = episodes[index].id
                                                print("📍 [EPISODE] Selected index \(index): aid=\(resolvedAid ?? -1), epId=\(resolvedEpId ?? -1)")
                                            }) {
                                                Text(episodes[index].title ?? "\(index + 1)")
                                                    .frame(maxWidth: .infinity)
                                                    .padding()
                                                    .background(selectedEpisodeIndex == index ? Color.bilibiliPink.opacity(0.3) : Color.clear)
                                                    .cornerRadius(10)
                                            }
                                            .buttonStyle(.card)
                                            .focused($focusedItem, equals: .episode(index))
                                        }
                                    }
                                }
                            }
                        } else if isLoading {
                            ProgressView()
                        } else if let error = errorMessage {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.trailing, 40)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .focusSection() // Group 2
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(60)
        .onAppear {
            focusedItem = .playButton
            loadDetail()
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let aid = resolvedAid, let cid = resolvedCid {
                PlayerView(aid: aid, cid: cid, epId: resolvedEpId, title: video.displayTitle, author: video.displayAuthor, isPresented: $showPlayer)
            }
        }
        .navigationTitle("Details")
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
    
    private func loadDetail() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // Delay a bit to let the navigation animation finish smoothly
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            do {
                if video.isBangumi {
                    let bangumi = try await BilibiliApiService.shared.fetchBangumiDetail(seasonId: video.seasonId, epId: video.episodeId)
                    bangumiDetail = bangumi
                    // Use the first episode's IDs for initial state
                    if let firstEp = bangumi.episodes?.first {
                        resolvedAid = firstEp.aid
                        resolvedCid = firstEp.cid
                        resolvedEpId = firstEp.id
                        print("📡 [BANGUMI] Resolved from episode: aid=\(resolvedAid ?? -1), cid=\(resolvedCid ?? -1), epId=\(resolvedEpId ?? -1)")
                    }
                } else {
                    let bvid = video.videoBvid
                    let aid = bvid == nil ? video.videoAid : nil
                    let detail = try await BilibiliApiService.shared.fetchVideoDetail(aid: aid, bvid: bvid)
                    videoDetail = detail
                    resolvedAid = detail.aid
                    resolvedCid = detail.cid ?? detail.pages?.first?.cid
                    resolvedEpId = nil
                    print("📡 [UGC] Resolved from detail: aid=\(resolvedAid ?? -1), cid=\(resolvedCid ?? -1)")
                }
                
                isLoading = false
            } catch {
                print("❌ [DETAIL] Error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                isLoading = false
                
                // Last ditch fallback for UGC
                if !video.isBangumi {
                    if resolvedAid == nil { resolvedAid = video.playerArgs?.aid ?? video.videoAid }
                    if resolvedCid == nil { resolvedCid = video.playerArgs?.cid }
                }
            }
        }
    }
}
