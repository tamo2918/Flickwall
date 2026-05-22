import Foundation
import Combine

@MainActor
final class WallpaperStore: ObservableObject {
    @Published private(set) var wallpapers: [WallpaperItem] = [] {
        didSet {
            saveWallpapers()
        }
    }

    @Published private(set) var folderSources: [WallpaperFolderSource] = [] {
        didSet {
            saveFolderSources()
        }
    }

    @Published var selectionID: WallpaperItem.ID? {
        didSet {
            saveSelection()
        }
    }

    private let defaults: UserDefaults
    private let libraryStorage: WallpaperLibraryStorage
    private let folderSourceStorage: WallpaperFolderSourceStorage
    private let legacyWallpapersKey = "wallpapers.v1"
    private let selectionKey = "selection.v1"

    init(
        defaults: UserDefaults = .standard,
        libraryStorage: WallpaperLibraryStorage = WallpaperLibraryStorage(),
        folderSourceStorage: WallpaperFolderSourceStorage = WallpaperFolderSourceStorage()
    ) {
        self.defaults = defaults
        self.libraryStorage = libraryStorage
        self.folderSourceStorage = folderSourceStorage
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

    @discardableResult
    func addFolderSources(_ sources: [WallpaperFolderSource]) -> [WallpaperFolderSource] {
        guard !sources.isEmpty else {
            return []
        }

        var nextSources = folderSources
        var canonicalSources: [WallpaperFolderSource] = []
        var knownPaths = Set(nextSources.map(\.path))

        for source in sources {
            if let existingSource = nextSources.first(where: { $0.path == source.path }) {
                canonicalSources.append(existingSource)
                continue
            }

            guard !knownPaths.contains(source.path) else {
                continue
            }

            knownPaths.insert(source.path)
            nextSources.append(source)
            canonicalSources.append(source)
        }

        if nextSources != folderSources {
            folderSources = nextSources
        }

        return canonicalSources
    }

    @discardableResult
    func syncFolderScan(_ scan: FileImportService.FolderScanResult) -> FolderSyncSummary {
        var summary = FolderSyncSummary(
            discoveredImageCount: scan.importResult.discoveredImageCount,
            failedItemCount: scan.importResult.failedItemCount,
            didScan: scan.didScan
        )

        guard scan.didScan else {
            return summary
        }

        if updateFolderSource(scan.source) {
            summary.updatedCount += 1
        }

        let sourceID = scan.source.id
        let scannedItems = scan.importResult.importedItems
        let scannedByPath = Dictionary(scannedItems.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        var matchedPaths = Set<String>()

        var refreshedWallpapers = wallpapers
        for index in refreshedWallpapers.indices where refreshedWallpapers[index].sourceFolderID == sourceID {
            if (try? refreshedWallpapers[index].refreshStoredLocation()) == true {
                summary.updatedCount += 1
            }
        }

        var nextWallpapers: [WallpaperItem] = []
        nextWallpapers.reserveCapacity(max(refreshedWallpapers.count, scannedItems.count))

        for item in refreshedWallpapers {
            let isManagedByFolder = item.sourceFolderID == sourceID

            if let scannedItem = scannedByPath[item.path], isManagedByFolder || item.sourceFolderID == nil {
                let updatedItem = item.updatingMetadata(from: scannedItem, sourceFolderID: sourceID)
                if updatedItem != item {
                    summary.updatedCount += 1
                }

                matchedPaths.insert(updatedItem.path)
                nextWallpapers.append(updatedItem)
            } else if isManagedByFolder {
                summary.removedCount += 1
            } else {
                nextWallpapers.append(item)
            }
        }

        var knownPaths = Set(nextWallpapers.map(\.path))
        for scannedItem in scannedItems where !matchedPaths.contains(scannedItem.path) {
            guard !knownPaths.contains(scannedItem.path) else {
                continue
            }

            knownPaths.insert(scannedItem.path)
            nextWallpapers.append(scannedItem)
            summary.addedCount += 1
        }

        if nextWallpapers != wallpapers {
            wallpapers = nextWallpapers

            if let selectionID, !nextWallpapers.contains(where: { $0.id == selectionID }) {
                self.selectionID = nextWallpapers.first?.id
            } else if selectionID == nil {
                selectionID = nextWallpapers.first?.id
            }

            ThumbnailCache.shared.removeAll()
        }

        return summary
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
        if let decoded = try? libraryStorage.load() {
            wallpapers = decoded
        } else if let data = defaults.data(forKey: legacyWallpapersKey),
                  let decoded = try? JSONDecoder().decode([WallpaperItem].self, from: data) {
            wallpapers = decoded
            try? libraryStorage.save(decoded)
            defaults.removeObject(forKey: legacyWallpapersKey)
        }

        if let decodedSources = try? folderSourceStorage.load() {
            folderSources = decodedSources
        }

        if let selectionString = defaults.string(forKey: selectionKey) {
            selectionID = UUID(uuidString: selectionString)
        }

        if selectionID == nil {
            selectionID = wallpapers.first?.id
        }

        refreshStaleBookmarks()
    }

    private func saveWallpapers() {
        try? libraryStorage.save(wallpapers)
    }

    private func saveFolderSources() {
        try? folderSourceStorage.save(folderSources)
    }

    private func saveSelection() {
        defaults.set(selectionID?.uuidString, forKey: selectionKey)
    }

    private func refreshStaleBookmarks() {
        var refreshedSources = folderSources
        var didRefreshSources = false
        for index in refreshedSources.indices {
            if (try? refreshedSources[index].refreshStoredLocation()) == true {
                didRefreshSources = true
            }
        }

        if didRefreshSources {
            folderSources = refreshedSources
        }

        var refreshedWallpapers = wallpapers
        var didRefresh = false

        for index in refreshedWallpapers.indices {
            if (try? refreshedWallpapers[index].refreshStoredLocation()) == true {
                didRefresh = true
            }
        }

        if didRefresh {
            wallpapers = refreshedWallpapers
        }
    }

    private func updateFolderSource(_ source: WallpaperFolderSource) -> Bool {
        if let index = folderSources.firstIndex(where: { $0.id == source.id }) {
            guard folderSources[index] != source else {
                return false
            }

            folderSources[index] = source
            return true
        }

        folderSources.append(source)
        return true
    }
}

struct FolderSyncSummary: Sendable {
    var addedCount = 0
    var removedCount = 0
    var updatedCount = 0
    var discoveredImageCount = 0
    var failedItemCount = 0
    var didScan = true

    var didChangeLibrary: Bool {
        addedCount > 0 || removedCount > 0 || updatedCount > 0
    }

    mutating func merge(_ summary: FolderSyncSummary) {
        addedCount += summary.addedCount
        removedCount += summary.removedCount
        updatedCount += summary.updatedCount
        discoveredImageCount += summary.discoveredImageCount
        failedItemCount += summary.failedItemCount
        didScan = didScan && summary.didScan
    }
}

private extension WallpaperItem {
    func updatingMetadata(from scannedItem: WallpaperItem, sourceFolderID: UUID) -> WallpaperItem {
        WallpaperItem(
            id: id,
            displayName: scannedItem.displayName,
            path: scannedItem.path,
            bookmarkData: scannedItem.bookmarkData,
            sourceFolderID: sourceFolderID,
            contentFingerprint: scannedItem.contentFingerprint,
            addedAt: addedAt,
            lastUsedAt: lastUsedAt,
            isFavorite: isFavorite
        )
    }
}
