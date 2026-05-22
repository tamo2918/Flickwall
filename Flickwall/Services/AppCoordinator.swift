import AppKit
import Combine
import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    let store: WallpaperStore
    let shortcutStore: ShortcutStore

    @Published var lastError: String?
    @Published var isImporting = false

    private let applier = WallpaperApplier()
    private let statusBarController = StatusBarController()
    private let folderChangeMonitor = FolderChangeMonitor()
    private var hotKey: GlobalHotKey?
    private var hotKeyObserver: NSObjectProtocol?
    private var didStart = false

    var openMainWindow: (() -> Void)?

    private lazy var overlayController = WallpaperOverlayController(
        store: store,
        onApply: { [weak self] in
            self?.applySelectedFromOverlay()
        },
        onCancel: { [weak self] in
            self?.hideSwitcher()
        }
    )

    init(store: WallpaperStore, shortcutStore: ShortcutStore) {
        self.store = store
        self.shortcutStore = shortcutStore
        configureStatusBar()
    }

    deinit {
        if let hotKeyObserver {
            NotificationCenter.default.removeObserver(hotKeyObserver)
        }
    }

    func start() {
        guard !didStart else {
            return
        }

        didStart = true
        statusBarController.install()
        installHotKey()
        configureFolderMonitoring()
        syncFolderSources(store.folderSources, userInitiated: false)
    }

    func addImages() {
        let urls = FileImportService.chooseImageFiles()
        guard !urls.isEmpty else {
            return
        }

        importWallpapers(emptyMessage: "No supported image files were selected.") {
            await FileImportService.wallpaperItems(from: urls)
        }
    }

    func addFolder() {
        let folders = FileImportService.chooseFolders()
        guard !folders.isEmpty else {
            return
        }

        guard !isImporting else {
            lastError = "Flickwall is still importing images."
            return
        }

        let sources = folders.compactMap { try? WallpaperFolderSource.make(from: $0) }
        guard !sources.isEmpty else {
            lastError = "Flickwall could not save access to the selected folder."
            return
        }

        let canonicalSources = store.addFolderSources(sources)
        folderChangeMonitor.update(sources: store.folderSources)
        syncFolderSources(canonicalSources, userInitiated: true)
    }

    private func importWallpapers(
        emptyMessage: String,
        operation: @escaping () async -> FileImportService.ImportResult
    ) {
        guard !isImporting else {
            lastError = "Flickwall is still importing images."
            return
        }

        isImporting = true

        Task { [weak self] in
            let result = await operation()
            guard let self else {
                return
            }

            isImporting = false
            addImportedItems(result, emptyMessage: emptyMessage)
        }
    }

    private func addImportedItems(_ result: FileImportService.ImportResult, emptyMessage: String) {
        guard result.discoveredImageCount > 0 else {
            lastError = emptyMessage
            return
        }

        guard !result.importedItems.isEmpty else {
            lastError = "Found image files, but Flickwall could not save access to them. Select the file or folder again."
            return
        }

        let addedCount = store.addImageItems(result.importedItems)

        if addedCount == 0 {
            lastError = "Those images are already in your library."
        } else if result.failedItemCount > 0 {
            lastError = "Added \(addedCount) images. \(result.failedItemCount) images could not be imported."
        }
    }

    func showSwitcher() {
        guard !store.wallpapers.isEmpty else {
            lastError = "Add wallpapers before opening the switcher."
            return
        }

        overlayController.show()
    }

    func hideSwitcher() {
        overlayController.hide()
    }

    func applySelected() {
        guard let item = store.selectedWallpaper else {
            return
        }

        do {
            try applier.apply(item)
            store.markApplied(item)
        } catch {
            lastError = "Could not apply \"\(item.displayName)\": \(error.localizedDescription)"
        }
    }

    func apply(_ item: WallpaperItem) {
        store.select(item)
        applySelected()
    }

    func toggleFavorite(_ item: WallpaperItem) {
        store.toggleFavorite(item)
    }

    func remove(_ item: WallpaperItem) {
        store.remove(item)
    }

    func revealInFinder(_ item: WallpaperItem) {
        try? item.withSecurityScopedURL { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func clearError() {
        lastError = nil
    }

    func openLibrary() {
        openMainWindow?()
    }

    func updateShortcut(_ shortcut: HotKeyShortcut) {
        guard shortcut != shortcutStore.shortcut else {
            return
        }

        let previousShortcut = shortcutStore.shortcut
        hotKey?.unregister()
        hotKey = nil

        do {
            hotKey = try GlobalHotKey(shortcut: shortcut)
            shortcutStore.setShortcut(shortcut)
            statusBarController.updateShortcutDisplay(shortcut.displayText)
            lastError = nil
        } catch {
            hotKey = try? GlobalHotKey(shortcut: previousShortcut)
            lastError = "Could not use \(shortcut.displayText): \(error.localizedDescription)"
        }
    }

    private func configureStatusBar() {
        statusBarController.onOpenLibrary = { [weak self] in
            self?.openLibrary()
        }
        statusBarController.onShowSwitcher = { [weak self] in
            self?.showSwitcher()
        }
        statusBarController.onAddImages = { [weak self] in
            self?.addImages()
        }
        statusBarController.onAddFolder = { [weak self] in
            self?.addFolder()
        }
        statusBarController.updateShortcutDisplay(shortcutStore.shortcut.displayText)
    }

    private func configureFolderMonitoring() {
        folderChangeMonitor.onFolderChanged = { [weak self] source in
            self?.syncFolderSources([source], userInitiated: false)
        }
        folderChangeMonitor.update(sources: store.folderSources)
    }

    private func installHotKey() {
        do {
            hotKey = try GlobalHotKey(shortcut: shortcutStore.shortcut)
            hotKeyObserver = NotificationCenter.default.addObserver(
                forName: flickwallHotKeyNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleHotKey()
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func handleHotKey() {
        guard !store.wallpapers.isEmpty else {
            NSSound.beep()
            return
        }

        if overlayController.isVisible {
            store.selectNext()
        } else {
            overlayController.show(applyOnShortcutRelease: shortcutStore.shortcut)
        }
    }

    private func applySelectedFromOverlay() {
        applySelected()
        overlayController.hide()
    }

    private func syncFolderSources(_ sources: [WallpaperFolderSource], userInitiated: Bool) {
        guard !sources.isEmpty else {
            return
        }

        if userInitiated {
            isImporting = true
        }

        Task { [weak self] in
            let scans = await FileImportService.scanFolderSources(sources)
            guard let self else {
                return
            }

            var combinedSummary = FolderSyncSummary()
            for scan in scans {
                let summary = store.syncFolderScan(scan)
                combinedSummary.merge(summary)
            }

            folderChangeMonitor.update(sources: store.folderSources)

            if userInitiated {
                isImporting = false
                reportFolderSync(combinedSummary)
            }
        }
    }

    private func reportFolderSync(_ summary: FolderSyncSummary) {
        if !summary.didScan {
            lastError = "Flickwall could not access one or more selected folders. Select the folder again if it was moved."
        } else if summary.discoveredImageCount == 0 {
            lastError = "The folder was added. New image files will appear automatically when they are added."
        } else if summary.addedCount == 0 && summary.removedCount == 0 && summary.updatedCount == 0 {
            lastError = "That folder is already up to date."
        } else if summary.failedItemCount > 0 {
            lastError = "Synced \(summary.addedCount) images. \(summary.failedItemCount) images could not be imported."
        } else {
            lastError = nil
        }
    }
}
