import SwiftUI

struct WallpaperSwitcherOverlay: View {
    @ObservedObject var store: WallpaperStore

    var body: some View {
        GlassEffectContainer(spacing: 36) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Text("Flickwall")
                        .font(.headline)

                    Spacer()

                    Text(store.selectedWallpaper?.displayName ?? "")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(store.wallpapers) { item in
                                SwitcherThumbnail(
                                    item: item,
                                    isSelected: store.selectionID == item.id
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: store.selectionID) { _, id in
                        guard let id else {
                            return
                        }

                        withAnimation(.snappy(duration: 0.18)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
            .padding(22)
            .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 28, y: 16)
        }
        .padding(8)
    }
}

private struct SwitcherThumbnail: View {
    let item: WallpaperItem
    let isSelected: Bool

    private let thumbnailWidth: CGFloat = 160
    private let thumbnailHeight: CGFloat = 102
    private let cellWidth: CGFloat = 176

    var body: some View {
        VStack(spacing: 8) {
            WallpaperThumbnailView(item: item)
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.22), lineWidth: isSelected ? 3 : 1)
                }

            Text(item.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: cellWidth)
                .lineLimit(1)
        }
        .frame(width: cellWidth, height: 132)
    }
}
