import SwiftUI
import AVKit
import Combine
import UIKit

struct PlayerView: View {
    enum VideoQuality: Int, CaseIterable, Identifiable {
        case p360 = 16
        case p480 = 32
        case p720 = 64
        case p1080 = 80
        
        var id: Int { rawValue }
        
        var label: String {
            switch self {
            case .p360: return "360p"
            case .p480: return "480p"
            case .p720: return "720p"
            case .p1080: return "1080p"
            }
        }
    }
    
    let aid: Int
    let cid: Int
    let epId: Int?
    let title: String
    let author: String
    @Binding var isPresented: Bool
    
    @State private var player: AVPlayer?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var selectedQuality: VideoQuality = .p720
    @State private var danmakuEnabled = true
    @State private var danmakuItems: [DanmakuItem] = []
    @State private var danmakuIndex = 0
    @State private var danmakuRowIndex = 0
    @State private var activeDanmaku: [ActiveDanmaku] = []
    @State private var timeObserverToken: Any?
    
    init(aid: Int, cid: Int, epId: Int? = nil, title: String, author: String, isPresented: Binding<Bool>) {
        self.aid = aid
        self.cid = cid
        self.epId = epId
        self.title = title
        self.author = author
        self._isPresented = isPresented
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                NativeVideoPlayer(
                    player: player,
                    qualities: VideoQuality.allCases,
                    selectedQuality: $selectedQuality,
                    danmakuEnabled: $danmakuEnabled
                )
                    .edgesIgnoringSafeArea(.all)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            GeometryReader { geo in
                DanmakuOverlay(
                    items: activeDanmaku,
                    enabled: danmakuEnabled,
                    width: geo.size.width,
                    height: geo.size.height
                )
            }
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
            
            if isLoading && errorMessage == nil {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                    Text(epId != nil ? "Connecting to PGC Stream..." : "Connecting to Bilibili...")
                        .foregroundColor(.white)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 100)
                        .lineLimit(1)
                }
            }
            
            if let error = errorMessage {
                VStack(spacing: 30) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 80))
                        .foregroundColor(.yellow)
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Close") {
                        isPresented = false
                    }
                    .buttonStyle(.card)
                }
            }
        }
        .task {
            // Setup Audio Session for tvOS
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("⚠️ [PLAYER] Failed to set audio session: \(error)")
            }
            
            await preparePlayer()
        }
        .onChange(of: selectedQuality) { _, newValue in
            print("🎚️ [PLAYER] Quality changed to \(newValue.label)")
            Task {
                await preparePlayer()
            }
        }
        .onChange(of: danmakuEnabled) { _, isEnabled in
            if !isEnabled {
                activeDanmaku = []
            }
        }
    }
    
    private func preparePlayer() async {
        isLoading = true
        errorMessage = nil
        
        // Save current time to resume after quality switch
        let currentTime = player?.currentTime()
        
        player?.pause()
        removeTimeObserver()
        resetDanmaku()
        
        do {
            let playUrlResponse: PlayUrlResponse
            if let epId = epId {
                print("📡 [PLAYER] Fetching PGC URL for epId: \(epId), cid: \(cid), qn: \(selectedQuality.rawValue)")
                playUrlResponse = try await BilibiliApiService.shared.fetchPgcPlayUrl(epId: epId, cid: cid, qn: selectedQuality.rawValue)
            } else {
                print("📡 [PLAYER] Fetching UGC URL for aid: \(aid), cid: \(cid), qn: \(selectedQuality.rawValue)")
                playUrlResponse = try await BilibiliApiService.shared.fetchPlayUrl(aid: aid, cid: cid, qn: selectedQuality.rawValue)
            }
            
            guard let videoUrlString = playUrlResponse.durl?.first?.url else {
                throw NSError(domain: "Player", code: -1, userInfo: [NSLocalizedDescriptionKey: "No stream URL found"])
            }
            
            var secureUrlString = videoUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
            if secureUrlString.hasPrefix("http://") {
                secureUrlString = secureUrlString.replacingOccurrences(of: "http://", with: "https://", range: secureUrlString.range(of: "http://"))
            }
            
            guard let videoUrl = URL(string: secureUrlString) else {
                throw NSError(domain: "Player", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL format"])
            }
            
            print("🔗 [PLAYER] URL Resolved: \(secureUrlString)")
            
            // Web Headers
            let headers: [String: String] = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Referer": "https://www.bilibili.com/",
                "Accept": "*/*"
            ]
            
            let asset = AVURLAsset(url: videoUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            let playerItem = AVPlayerItem(asset: asset)
            
            // Add Metadata for Now Playing info
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = .commonIdentifierTitle
            titleItem.value = title as NSString
            titleItem.extendedLanguageTag = "und"
            
            let artistItem = AVMutableMetadataItem()
            artistItem.identifier = .commonIdentifierArtist
            artistItem.value = author as NSString
            artistItem.extendedLanguageTag = "und"
            
            playerItem.externalMetadata = [titleItem, artistItem]
            
            let newPlayer = AVPlayer(playerItem: playerItem)
            
            if let time = currentTime {
                await newPlayer.seek(to: time)
            }
            
            self.player = newPlayer
            self.isLoading = false
            newPlayer.play()
            
            await loadDanmakuIfNeeded()
            attachTimeObserver(to: newPlayer)
            
            // Log status
            for await status in playerItem.publisher(for: \.status).values {
                print("📊 [PLAYER] Item Status: \(status.rawValue)")
                if status == .failed {
                    self.errorMessage = playerItem.error?.localizedDescription ?? "Playback failed"
                    break
                }
                if status == .readyToPlay {
                    print("🎬 [PLAYER] Content is playing.")
                    break
                }
            }
        } catch {
            print("❌ [PLAYER] Setup Error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    private func loadDanmakuIfNeeded() async {
        guard danmakuItems.isEmpty else { return }
        do {
            let items = try await BilibiliApiService.shared.fetchDanmaku(cid: cid)
            danmakuItems = items.sorted { $0.time < $1.time }
            danmakuIndex = 0
            danmakuRowIndex = 0
        } catch {
            print("⚠️ [DANMAKU] Failed to load: \(error.localizedDescription)")
        }
    }
    
    private func attachTimeObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard danmakuEnabled else { return }
            let currentTime = time.seconds
            while danmakuIndex < danmakuItems.count,
                  danmakuItems[danmakuIndex].time <= currentTime + 0.05 {
                let item = danmakuItems[danmakuIndex]
                danmakuIndex += 1
                spawnDanmaku(item: item)
            }
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    private func resetDanmaku() {
        activeDanmaku = []
        danmakuIndex = 0
        danmakuRowIndex = 0
    }
    
    private func spawnDanmaku(item: DanmakuItem) {
        let row = danmakuRowIndex % 10
        danmakuRowIndex += 1
        let active = ActiveDanmaku(text: item.text, row: row)
        if activeDanmaku.count >= 60 {
            activeDanmaku.removeFirst(activeDanmaku.count - 59)
        }
        activeDanmaku.append(active)
        DispatchQueue.main.asyncAfter(deadline: .now() + active.duration) {
            activeDanmaku.removeAll { $0.id == active.id }
        }
    }
}

struct NativeVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    let qualities: [PlayerView.VideoQuality]
    @Binding var selectedQuality: PlayerView.VideoQuality
    @Binding var danmakuEnabled: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: NativeVideoPlayer
        
        init(_ parent: NativeVideoPlayer) {
            self.parent = parent
        }
        
        func buildMenu() -> UIMenu {
            let actions = parent.qualities.map { quality in
                UIAction(title: quality.label, state: parent.selectedQuality == quality ? .on : .off) { [weak self] _ in
                    self?.parent.selectedQuality = quality
                }
            }
            return UIMenu(title: "Quality", image: UIImage(systemName: "gearshape"), children: actions)
        }
        
        func buildDanmakuMenu() -> UIMenu {
            let onAction = UIAction(title: "On", state: parent.danmakuEnabled ? .on : .off) { [weak self] _ in
                self?.parent.danmakuEnabled = true
            }
            let offAction = UIAction(title: "Off", state: parent.danmakuEnabled ? .off : .on) { [weak self] _ in
                self?.parent.danmakuEnabled = false
            }
            return UIMenu(title: "Danmaku", image: UIImage(systemName: "text.bubble"), children: [onAction, offAction])
        }
    }
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.transportBarCustomMenuItems = [
            context.coordinator.buildMenu(),
            context.coordinator.buildDanmakuMenu()
        ]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.transportBarCustomMenuItems = [
            context.coordinator.buildMenu(),
            context.coordinator.buildDanmakuMenu()
        ]
    }
}

private struct ActiveDanmaku: Identifiable {
    let id = UUID()
    let text: String
    let row: Int
    let duration: Double = 8.0
}

private struct DanmakuOverlay: View {
    let items: [ActiveDanmaku]
    let enabled: Bool
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        if enabled {
            ZStack(alignment: .topLeading) {
                ForEach(items) { item in
                    DanmakuRow(
                        text: item.text,
                        y: yPosition(for: item.row),
                        width: width,
                        duration: item.duration
                    )
                }
            }
            .frame(width: width, height: height)
        }
    }
    
    private func yPosition(for row: Int) -> CGFloat {
        let rowHeight: CGFloat = 36
        let topPadding: CGFloat = 80
        return topPadding + CGFloat(row) * rowHeight
    }
}

private struct DanmakuRow: View {
    let text: String
    let y: CGFloat
    let width: CGFloat
    let duration: Double
    
    @State private var offsetX: CGFloat = 0
    
    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .semibold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
            .offset(x: offsetX, y: y)
            .onAppear {
                offsetX = width + 40
                withAnimation(.linear(duration: duration)) {
                    offsetX = -width - 200
                }
            }
    }
}
