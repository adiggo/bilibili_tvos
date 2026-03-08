import SwiftUI

struct VideoDetailView: View {
    let video: VideoItem
    @State private var videoDetail: VideoDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showPlayer = false
    @State private var resolvedAid: Int?
    @State private var resolvedCid: Int?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack(alignment: .top, spacing: 60) {
            // Left Side: Thumbnail and Play Button
            VStack(spacing: 40) {
                CachedAsyncImage(
                    urlString: video.displayCover,
                    targetSize: CGSize(width: 800, height: 450),
                    contentMode: .fit,
                    cornerRadius: 20,
                    placeholder: Rectangle().fill(Color.gray)
                )
                
                Button(action: {
                    print("🔘 [CLICK] PLAY BUTTON CLICKED!")
                    if resolvedAid != nil && resolvedCid != nil {
                        showPlayer = true
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Play Video")
                    }
                    .padding()
                }
                .buttonStyle(.card)
                .disabled(resolvedAid == nil || resolvedCid == nil)
                
                // On-screen debug info
                Text("AID: \(resolvedAid ?? -1) | CID: \(resolvedCid ?? -1)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 20)
            }
            
            // Right Side: Meta Data
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
                    
                    Text(video.displayAuthor)
                        .font(.headline)
                }
                
                if let detail = videoDetail {
                    Text(detail.desc ?? "No description available")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(10)
                } else if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(60)
        .onAppear {
            loadDetail()
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if let aid = resolvedAid, let cid = resolvedCid {
                PlayerView(aid: aid, cid: cid, isPresented: $showPlayer)
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
            do {
                // Try bvid first, then aid
                let bvid = video.videoBvid
                let aid = bvid == nil ? video.videoAid : nil
                
                print("📥 [DETAIL] VideoDetailView: Starting loadDetail (aid: \(aid != nil ? "\(aid!)" : "nil"), bvid: \(bvid ?? "nil"))")
                
                videoDetail = try await BilibiliApiService.shared.fetchVideoDetail(aid: aid, bvid: bvid)
                print("📡 [DETAIL] API Response received. aid=\(videoDetail?.aid ?? -1), cid=\(videoDetail?.cid ?? -1)")
                
                resolvedAid = videoDetail?.aid
                resolvedCid = videoDetail?.cid ?? videoDetail?.pages?.first?.cid
                
                print("✅ [DETAIL] Resolved IDs: aid=\(resolvedAid != nil ? "\(resolvedAid!)" : "NIL"), cid=\(resolvedCid != nil ? "\(resolvedCid!)" : "NIL")")
                isLoading = false
            } catch {
                print("❌ [DETAIL] Error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                isLoading = false
                
                // Fallback
                if resolvedAid == nil { resolvedAid = video.playerArgs?.aid ?? video.videoAid }
                if resolvedCid == nil { resolvedCid = video.playerArgs?.cid }
            }
        }
    }
}
