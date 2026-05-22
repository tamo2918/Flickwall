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
        .onAppear(perform: load)
        .onChange(of: item.id) {
            load()
        }
    }

    private func load() {
        image = try? item.withSecurityScopedURL { url in
            NSImage(contentsOf: url)
        }
    }
}
