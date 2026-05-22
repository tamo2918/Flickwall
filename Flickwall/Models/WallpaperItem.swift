import Foundation

struct WallpaperItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var path: String
    var bookmarkData: Data
    var sourceFolderID: UUID?
    var contentFingerprint: String?
    var addedAt: Date
    var lastUsedAt: Date?
    var isFavorite: Bool

    nonisolated init(
        id: UUID = UUID(),
        displayName: String,
        path: String,
        bookmarkData: Data,
        sourceFolderID: UUID? = nil,
        contentFingerprint: String? = nil,
        addedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.bookmarkData = bookmarkData
        self.sourceFolderID = sourceFolderID
        self.contentFingerprint = contentFingerprint
        self.addedAt = addedAt
        self.lastUsedAt = lastUsedAt
        self.isFavorite = isFavorite
    }

    nonisolated static func make(from url: URL, sourceFolderID: UUID? = nil) throws -> WallpaperItem {
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
            bookmarkData: bookmarkData,
            sourceFolderID: sourceFolderID,
            contentFingerprint: contentFingerprint(for: url)
        )
    }

    nonisolated func resolvedURL() throws -> URL {
        try resolveBookmark().url
    }

    @discardableResult
    nonisolated mutating func refreshBookmarkIfNeeded() throws -> Bool {
        try refreshStoredLocation()
    }

    @discardableResult
    nonisolated mutating func refreshStoredLocation() throws -> Bool {
        let resolved = try resolveBookmark()
        let refreshed = try WallpaperItem.make(from: resolved.url, sourceFolderID: sourceFolderID)

        let didChange = resolved.isStale ||
            displayName != refreshed.displayName ||
            path != refreshed.path ||
            bookmarkData != refreshed.bookmarkData ||
            contentFingerprint != refreshed.contentFingerprint

        displayName = refreshed.displayName
        path = refreshed.path
        bookmarkData = refreshed.bookmarkData
        contentFingerprint = refreshed.contentFingerprint

        return didChange
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

    private nonisolated static func contentFingerprint(for url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return nil
        }

        let modificationTime = values.contentModificationDate?.timeIntervalSinceReferenceDate ?? 0
        let fileSize = values.fileSize ?? 0
        return "\(modificationTime)-\(fileSize)"
    }
}
