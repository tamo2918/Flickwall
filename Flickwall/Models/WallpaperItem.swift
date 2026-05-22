import Foundation

struct WallpaperItem: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var path: String
    var bookmarkData: Data
    var addedAt: Date
    var lastUsedAt: Date?
    var isFavorite: Bool

    init(
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

    static func make(from url: URL) throws -> WallpaperItem {
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

    func resolvedURL() throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        guard !isStale else {
            throw WallpaperItemError.staleBookmark(displayName)
        }

        return url
    }

    func withSecurityScopedURL<T>(_ body: (URL) throws -> T) throws -> T {
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

enum WallpaperItemError: LocalizedError {
    case staleBookmark(String)

    var errorDescription: String? {
        switch self {
        case .staleBookmark(let name):
            return "The saved file permission for \"\(name)\" is stale. Add the image again."
        }
    }
}
