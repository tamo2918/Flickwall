import Foundation

struct WallpaperFolderSourceStorage: Sendable {
    private let fileURL: URL

    nonisolated init(fileURL: URL = WallpaperFolderSourceStorage.defaultFileURL()) {
        self.fileURL = fileURL
    }

    nonisolated func load() throws -> [WallpaperFolderSource]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([WallpaperFolderSource].self, from: data)
    }

    nonisolated func save(_ sources: [WallpaperFolderSource]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(sources)
        try data.write(to: fileURL, options: [.atomic])
    }

    private nonisolated static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return baseURL
            .appendingPathComponent("Flickwall", isDirectory: true)
            .appendingPathComponent("folders.json")
    }
}
