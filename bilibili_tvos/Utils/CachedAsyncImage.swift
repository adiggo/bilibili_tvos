import SwiftUI
import UIKit
import ImageIO

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 300
    }
    
    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var currentUrl: String?
    
    func load(urlString: String, targetSize: CGSize, scale: CGFloat = UIScreen.main.scale) {
        guard !urlString.isEmpty else {
            image = nil
            return
        }
        if currentUrl == urlString, image != nil {
            return
        }
        currentUrl = urlString
        if let cached = ImageCache.shared.image(forKey: urlString) {
            image = cached
            return
        }
        guard let url = URL(string: urlString) else {
            image = nil
            return
        }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            if let downsampled = self.downsampleImage(data: data, targetSize: targetSize, scale: scale) {
                ImageCache.shared.set(downsampled, forKey: urlString)
                DispatchQueue.main.async {
                    if self.currentUrl == urlString {
                        self.image = downsampled
                    }
                }
            }
        }.resume()
    }
    
    private func downsampleImage(data: Data, targetSize: CGSize, scale: CGFloat) -> UIImage? {
        let maxDimension = max(targetSize.width, targetSize.height) * scale
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

struct CachedAsyncImage<Placeholder: View>: View {
    let urlString: String
    let targetSize: CGSize
    let contentMode: ContentMode
    let cornerRadius: CGFloat
    let placeholder: Placeholder
    
    @StateObject private var loader = ImageLoader()
    
    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .frame(width: targetSize.width, height: targetSize.height)
        .clipped()
        .cornerRadius(cornerRadius)
        .onAppear {
            loader.load(urlString: urlString, targetSize: targetSize)
        }
        .onChange(of: urlString) { _, newValue in
            loader.load(urlString: newValue, targetSize: targetSize)
        }
    }
}
