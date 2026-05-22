import Foundation

struct WallpaperItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var path: String
    var bookmarkData: Data
    var addedAt: Date
    var lastUsedAt: Date?
    var isFavorite: Bool

    nonisolated init(
        id: UUID = UUID(),
        displayName: String,
        path: String,
        bookmarkData: Data,
        addedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.bookmarkData = bookmarkData
        self.addedAt = addedAt
        self.lastUsedAt = lastUsedAt
        self.isFavorite = isFavorite
    }

    nonisolated static func make(from url: URL) throws -> WallpaperItem {
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

        return WallpaperItem(
            displayName: url.deletingPathExtension().lastPathComponent,
            path: url.standardizedFileURL.path,
            bookmarkData: bookmarkData
        )
    }

    nonisolated func resolvedURL() throws -> URL {
        try resolveBookmark().url
    }

    nonisolated mutating func refreshBookmarkIfNeeded() throws -> Bool {
        let resolved = try resolveBookmark()
        guard resolved.isStale else {
            return false
        }

        let refreshed = try WallpaperItem.make(from: resolved.url)
        path = refreshed.path
        bookmarkData = refreshed.bookmarkData
        return true
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
}
