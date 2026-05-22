import AppKit

@MainActor
final class WallpaperApplier {
    func apply(_ item: WallpaperItem) throws {
        try item.withSecurityScopedURL { url in
            for screen in NSScreen.screens {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            }
        }
    }
}
