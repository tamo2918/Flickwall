import AppKit
import SwiftUI

struct WallpaperThumbnailView: View {
    let item: WallpaperItem

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.16))

                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task(id: "\(item.id.uuidString)-\(item.path)") {
            await load()
        }
    }

    private func load() async {
        image = await ThumbnailCache.shared.image(for: item, maxPixelSize: 640)
    }
}
