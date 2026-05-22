import AppKit
import UniformTypeIdentifiers

enum FileImportService {
    struct ImportResult: Sendable {
        var discoveredImageCount = 0
        var importedItems: [WallpaperItem] = []
        var failedItemCount = 0

        nonisolated init(
            discoveredImageCount: Int = 0,
            importedItems: [WallpaperItem] = [],
            failedItemCount: Int = 0
        ) {
            self.discoveredImageCount = discoveredImageCount
            self.importedItems = importedItems
            self.failedItemCount = failedItemCount
        }

        nonisolated mutating func merge(_ result: ImportResult) {
            discoveredImageCount += result.discoveredImageCount
            importedItems.append(contentsOf: result.importedItems)
            failedItemCount += result.failedItemCount
        }
    }

    struct FolderScanResult: Sendable {
        var source: WallpaperFolderSource
        var importResult: ImportResult
        var didScan: Bool

        nonisolated init(
            source: WallpaperFolderSource,
            importResult: ImportResult = ImportResult(),
            didScan: Bool = true
        ) {
            self.source = source
            self.importResult = importResult
            self.didScan = didScan
        }
    }

    @MainActor
    static func chooseImageFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add"

        return panel.runModal() == .OK ? panel.urls : []
    }

    @MainActor
    static func chooseFolders() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.folder]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Add"

        return panel.runModal() == .OK ? panel.urls : []
    }

    nonisolated static func wallpaperItems(from urls: [URL]) async -> ImportResult {
        await Task.detached(priority: .userInitiated) {
            buildWallpaperItems(from: urls)
        }.value
    }

    nonisolated static func wallpaperItems(in folders: [URL]) async -> ImportResult {
        await Task.detached(priority: .userInitiated) {
            folders.reduce(into: ImportResult()) { result, folder in
                result.merge(wallpaperItems(in: folder))
            }
        }.value
    }

    nonisolated static func scanFolderSources(_ sources: [WallpaperFolderSource]) async -> [FolderScanResult] {
        await Task.detached(priority: .userInitiated) {
            sources.map { source in
                scanFolderSource(source)
            }
        }.value
    }

    private nonisolated static func buildWallpaperItems(from urls: [URL]) -> ImportResult {
        urls.reduce(into: ImportResult()) { result, url in
            guard isSupportedImage(url) else {
                return
            }

            result.discoveredImageCount += 1

            do {
                result.importedItems.append(try WallpaperItem.make(from: url))
            } catch {
                result.failedItemCount += 1
            }
        }
    }

    private nonisolated static func wallpaperItems(in folder: URL) -> ImportResult {
        let didStartAccessing = folder.startAccessingSecurityScopedResource()

        defer {
            if didStartAccessing {
                folder.stopAccessingSecurityScopedResource()
            }
        }

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .contentTypeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return ImportResult()
        }

        return buildWallpaperItems(from: enumerator.compactMap { entry in
            entry as? URL
        })
    }

    private nonisolated static func scanFolderSource(_ source: WallpaperFolderSource) -> FolderScanResult {
        var refreshedSource = source

        do {
            try refreshedSource.refreshStoredLocation()
        } catch {
            return FolderScanResult(source: source, didScan: false)
        }

        do {
            let result = try refreshedSource.withSecurityScopedURL { folder in
                wallpaperItems(in: folder, sourceFolderID: refreshedSource.id)
            }

            return FolderScanResult(source: refreshedSource, importResult: result, didScan: true)
        } catch {
            return FolderScanResult(source: refreshedSource, didScan: false)
        }
    }

    private nonisolated static func wallpaperItems(in folder: URL, sourceFolderID: UUID?) -> ImportResult {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .contentTypeKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return ImportResult()
        }

        return enumerator.reduce(into: ImportResult()) { result, entry in
            guard let url = entry as? URL else {
                return
            }

            guard isSupportedImage(url) else {
                return
            }

            result.discoveredImageCount += 1

            do {
                result.importedItems.append(try WallpaperItem.make(from: url, sourceFolderID: sourceFolderID))
            } catch {
                result.failedItemCount += 1
            }
        }
    }

    private nonisolated static func isSupportedImage(_ url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey]),
           values.isRegularFile == true,
           values.contentType?.conforms(to: .image) == true {
            return true
        }

        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }

        return type.conforms(to: .image)
    }
}
