import AppKit
import ImageIO

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 500
    }

    func image(for item: WallpaperItem, maxPixelSize: Int) async -> NSImage? {
        let key = "\(item.id.uuidString)-\(item.path)-\(maxPixelSize)" as NSString
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        let loadedImage = await Task.detached(priority: .utility) {
            SendableImage(image: Self.makeThumbnail(for: item, maxPixelSize: maxPixelSize))
        }.value.image

        if let loadedImage {
            cache.setObject(loadedImage, forKey: key)
        }

        return loadedImage
    }

    private nonisolated static func makeThumbnail(for item: WallpaperItem, maxPixelSize: Int) -> NSImage? {
        try? item.withSecurityScopedURL { url in
            let sourceOptions = [
                kCGImageSourceShouldCache: false
            ] as CFDictionary

            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
                return NSImage(contentsOf: url)
            }

            let thumbnailOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ] as CFDictionary

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions) else {
                return NSImage(contentsOf: url)
            }

            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
        }
    }
}

private struct SendableImage: @unchecked Sendable {
    let image: NSImage?
}
