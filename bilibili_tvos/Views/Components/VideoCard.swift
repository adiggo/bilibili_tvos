import SwiftUI

struct VideoCard: View {
    let video: VideoItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CachedAsyncImage(
                urlString: video.displayCover,
                targetSize: CGSize(width: 400, height: 225),
                contentMode: .fill,
                cornerRadius: 12,
                placeholder: Color.gray
            )
            .onAppear {
                if AppDebug.isEnabled {
                    print("🖼️ VideoCard for '\(video.displayTitle)' appeared at index \(video.idx ?? -1)")
                }
            }
            
            Text(video.displayTitle)
                .font(.headline)
                .lineLimit(2)
                .frame(width: 400, alignment: .leading)
                .foregroundColor(.primary)
            
            HStack {
                Text(video.displayAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let playCount = video.play {
                    Text("\(formatCount(playCount)) views")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 400)
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fW", Double(count) / 10000.0)
        }
        return "\(count)"
    }
}
