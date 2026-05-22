import AppKit

@MainActor
final class StatusBarController: NSObject {
    var onOpenLibrary: (() -> Void)?
    var onShowSwitcher: (() -> Void)?
    var onAddImages: (() -> Void)?
    var onAddFolder: (() -> Void)?

    private var statusItem: NSStatusItem?
    private var shortcutDisplay = HotKeyShortcut.defaultValue.displayText

    func install() {
        guard statusItem == nil else {
            rebuildMenu()
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "photo.on.rectangle.angled",
            accessibilityDescription: "Flickwall"
        )
        item.button?.imagePosition = .imageOnly
        statusItem = item
        rebuildMenu()
    }

    func updateShortcutDisplay(_ display: String) {
        shortcutDisplay = display
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Open Library", action: #selector(openLibrary), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Switcher (\(shortcutDisplay))", action: #selector(showSwitcher), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Add Images...", action: #selector(addImages), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Add Folder...", action: #selector(addFolder), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Flickwall", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
    }

    @objc private func openLibrary() {
        onOpenLibrary?()
    }

    @objc private func showSwitcher() {
        onShowSwitcher?()
    }

    @objc private func addImages() {
        onAddImages?()
    }

    @objc private func addFolder() {
        onAddFolder?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
