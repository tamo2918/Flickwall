import SwiftUI

struct WallpaperLibraryView: View {
    let title: String
    let items: [WallpaperItem]
    @ObservedObject var store: WallpaperStore
    @ObservedObject var coordinator: AppCoordinator

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 16)
    ]

    var body: some View {
        Group {
            if store.wallpapers.isEmpty {
                emptyLibrary
            } else if items.isEmpty {
                emptyFilter
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(items) { item in
                            WallpaperCard(
                                item: item,
                                isSelected: store.selectionID == item.id,
                                onSelect: { store.select(item) },
                                onApply: { coordinator.apply(item) },
                                onFavorite: { coordinator.toggleFavorite(item) },
                                onRemove: { coordinator.remove(item) },
                                onReveal: { coordinator.revealInFinder(item) }
                            )
                        }
                    }
                    .padding(20)
                }
                .safeAreaInset(edge: .bottom) {
                    selectedActionBar
                }
            }
        }
        .navigationTitle(title)
    }

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("No Wallpapers", systemImage: "photo.stack")
        } actions: {
            HStack {
                Button("Add Images") {
                    coordinator.addImages()
                }
                .disabled(coordinator.isImporting)

                Button("Add Folder") {
                    coordinator.addFolder()
                }
                .disabled(coordinator.isImporting)
            }
        }
    }

    private var emptyFilter: some View {
        ContentUnavailableView {
            Label("Nothing Here", systemImage: "tray")
        }
    }

    @ViewBuilder
    private var selectedActionBar: some View {
        if let item = store.selectedWallpaper {
            HStack(spacing: 12) {
                WallpaperThumbnailView(item: item)
                    .frame(width: 64, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(item.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button {
                    coordinator.toggleFavorite(item)
                } label: {
                    Label(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.fill" : "star")
                }

                Button {
                    coordinator.applySelected()
                } label: {
                    Label("Apply", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}

private struct WallpaperCard: View {
    let item: WallpaperItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onApply: () -> Void
    let onFavorite: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    WallpaperThumbnailView(item: item)
                        .aspectRatio(16 / 10, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .padding(7)
                            .background(.regularMaterial, in: Circle())
                            .padding(8)
                    }
                }

                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Apply", action: onApply)
            Button(item.isFavorite ? "Remove Favorite" : "Favorite", action: onFavorite)
            Button("Reveal in Finder", action: onReveal)
            Divider()
            Button("Remove", role: .destructive, action: onRemove)
        }
    }
}
