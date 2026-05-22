import Foundation
import Testing
@testable import Flickwall

@MainActor
struct FlickwallTests {
    @Test func folderScansReflectAddedRenamedAndRemovedImages() async throws {
        let fixture = try TestFixture()
        let folderURL = fixture.root.appendingPathComponent("Wallpapers", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let firstURL = folderURL.appendingPathComponent("one.png")
        let secondURL = folderURL.appendingPathComponent("two.png")
        try writePNG(to: firstURL)

        let source = try WallpaperFolderSource.make(from: folderURL)
        let store = fixture.makeStore()
        let sources = store.addFolderSources([source])

        let firstScan = try #require(await FileImportService.scanFolderSources(sources).first)
        let firstSummary = store.syncFolderScan(firstScan)
        #expect(firstSummary.addedCount == 1)
        #expect(store.wallpapers.map(\.displayName) == ["one"])
        #expect(store.wallpapers.first?.sourceFolderID == source.id)

        try writePNG(to: secondURL)
        let secondScan = try #require(await FileImportService.scanFolderSources(sources).first)
        let secondSummary = store.syncFolderScan(secondScan)
        #expect(secondSummary.addedCount == 1)
        #expect(Set(store.wallpapers.map(\.displayName)) == ["one", "two"])

        let renamedURL = folderURL.appendingPathComponent("renamed.png")
        try FileManager.default.moveItem(at: firstURL, to: renamedURL)
        let renameScan = try #require(await FileImportService.scanFolderSources(sources).first)
        _ = store.syncFolderScan(renameScan)
        #expect(Set(store.wallpapers.map(\.displayName)).contains("renamed"))
        #expect(!Set(store.wallpapers.map(\.path)).contains(firstURL.standardizedFileURL.path))

        try FileManager.default.removeItem(at: secondURL)
        let removalScan = try #require(await FileImportService.scanFolderSources(sources).first)
        _ = store.syncFolderScan(removalScan)
        #expect(store.wallpapers.count == 1)
        #expect(store.wallpapers.first?.displayName == "renamed")
    }

    @Test func folderSourcesArePersistedSeparatelyFromWallpaperItems() throws {
        let fixture = try TestFixture()
        let folderURL = fixture.root.appendingPathComponent("Source", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let source = try WallpaperFolderSource.make(from: folderURL)
        let firstStore = fixture.makeStore()
        firstStore.addFolderSources([source])

        let reloadedStore = fixture.makeStore()
        #expect(reloadedStore.folderSources.map(\.path) == [folderURL.standardizedFileURL.path])
        #expect(reloadedStore.wallpapers.isEmpty)
    }
}

private struct TestFixture {
    let root: URL
    let defaults: UserDefaults
    private let defaultsSuiteName: String

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlickwallTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        defaultsSuiteName = "FlickwallTests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    @MainActor
    func makeStore() -> WallpaperStore {
        WallpaperStore(
            defaults: defaults,
            libraryStorage: WallpaperLibraryStorage(fileURL: root.appendingPathComponent("wallpapers.json")),
            folderSourceStorage: WallpaperFolderSourceStorage(fileURL: root.appendingPathComponent("folders.json"))
        )
    }
}

private func writePNG(to url: URL) throws {
    let pngData = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="))
    try pngData.write(to: url, options: [.atomic])
}
