import Foundation
import Combine

@MainActor
final class WallpaperStore: ObservableObject {
    @Published private(set) var wallpapers: [WallpaperItem] = [] {
        didSet {
            saveWallpapers()
        }
    }

    @Published var selectionID: WallpaperItem.ID? {
        didSet {
            saveSelection()
        }
    }

    private let defaults: UserDefaults
    private let wallpapersKey = "wallpapers.v1"
    private let selectionKey = "selection.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectionID = nil
        load()
    }

    var selectedWallpaper: WallpaperItem? {
        if let selectionID, let selected = wallpapers.first(where: { $0.id == selectionID }) {
            return selected
        }

        return wallpapers.first
    }

    var favoriteWallpapers: [WallpaperItem] {
        wallpapers.filter(\.isFavorite)
    }

    var recentWallpapers: [WallpaperItem] {
        wallpapers
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
    }

    @discardableResult
    func addImageURLs(_ urls: [URL]) -> Int {
        let items = urls.compactMap { try? WallpaperItem.make(from: $0) }
        return addImageItems(items)
    }

    @discardableResult
    func addImageItems(_ items: [WallpaperItem]) -> Int {
        var knownPaths = Set(wallpapers.map(\.path))
        var newItems: [WallpaperItem] = []

        for item in items {
            let path = item.path
            guard !knownPaths.contains(path) else {
                continue
            }

            knownPaths.insert(path)
            newItems.append(item)
        }

        guard !newItems.isEmpty else {
            return 0
        }

        wallpapers.append(contentsOf: newItems)

        if selectionID == nil {
            selectionID = newItems.first?.id
        }

        return newItems.count
    }

    func select(_ item: WallpaperItem) {
        selectionID = item.id
    }

    func selectNext() {
        moveSelection(by: 1)
    }

    func selectPrevious() {
        moveSelection(by: -1)
    }

    func toggleFavorite(_ item: WallpaperItem) {
        guard let index = wallpapers.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        wallpapers[index].isFavorite.toggle()
    }

    func remove(_ item: WallpaperItem) {
        wallpapers.removeAll { $0.id == item.id }

        if selectionID == item.id {
            selectionID = wallpapers.first?.id
        }
    }

    func markApplied(_ item: WallpaperItem) {
        guard let index = wallpapers.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        wallpapers[index].lastUsedAt = Date()
        selectionID = item.id
    }

    private func moveSelection(by offset: Int) {
        guard !wallpapers.isEmpty else {
            selectionID = nil
            return
        }

        let currentIndex = selectionID.flatMap { id in
            wallpapers.firstIndex { $0.id == id }
        } ?? 0

        let nextIndex = (currentIndex + offset + wallpapers.count) % wallpapers.count
        selectionID = wallpapers[nextIndex].id
    }

    private func load() {
        if let data = defaults.data(forKey: wallpapersKey),
           let decoded = try? JSONDecoder().decode([WallpaperItem].self, from: data) {
            wallpapers = decoded
        }

        if let selectionString = defaults.string(forKey: selectionKey) {
            selectionID = UUID(uuidString: selectionString)
        }

        if selectionID == nil {
            selectionID = wallpapers.first?.id
        }
    }

    private func saveWallpapers() {
        guard let data = try? JSONEncoder().encode(wallpapers) else {
            return
        }

        defaults.set(data, forKey: wallpapersKey)
    }

    private func saveSelection() {
        defaults.set(selectionID?.uuidString, forKey: selectionKey)
    }
}
