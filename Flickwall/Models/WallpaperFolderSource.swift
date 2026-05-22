import Foundation

struct WallpaperFolderSource: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var path: String
    var bookmarkData: Data
    var addedAt: Date

    nonisolated init(
        id: UUID = UUID(),
        displayName: String,
        path: String,
        bookmarkData: Data,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.bookmarkData = bookmarkData
        self.addedAt = addedAt
    }

    nonisolated static func make(from url: URL) throws -> WallpaperFolderSource {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        return WallpaperFolderSource(
            displayName: url.lastPathComponent,
            path: url.standardizedFileURL.path,
            bookmarkData: bookmarkData
        )
    }

    nonisolated func resolvedURL() throws -> URL {
        try resolveBookmark().url
    }

    @discardableResult
    nonisolated mutating func refreshStoredLocation() throws -> Bool {
        let resolved = try resolveBookmark()
        let refreshed = try WallpaperFolderSource.make(from: resolved.url)

        let didChange = resolved.isStale ||
            displayName != refreshed.displayName ||
            path != refreshed.path ||
            bookmarkData != refreshed.bookmarkData

        displayName = refreshed.displayName
        path = refreshed.path
        bookmarkData = refreshed.bookmarkData

        return didChange
    }

    nonisolated func withSecurityScopedURL<T>(_ body: (URL) throws -> T) throws -> T {
        let url = try resolvedURL()
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try body(url)
    }

    private nonisolated func resolveBookmark() throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        return (url, isStale)
    }
}
