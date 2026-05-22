import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private weak var window: NSWindow?
    private var store: WallpaperStore?
    private var coordinator: AppCoordinator?

    func configure(store: WallpaperStore, coordinator: AppCoordinator) {
        self.store = store
        self.coordinator = coordinator
    }

    func attach(to window: NSWindow) {
        guard self.window !== window else {
            return
        }

        self.window = window
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.delegate = self
    }

    func showWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)

        guard let window = window ?? makeWindow() else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func makeWindow() -> NSWindow? {
        guard let store, let coordinator else {
            return nil
        }

        let contentView = ContentView(store: store, coordinator: coordinator)
            .frame(minWidth: 900, minHeight: 600)
            .background(MainWindowAccessor())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Flickwall"
        window.contentView = NSHostingView(rootView: contentView)
        window.minSize = NSSize(width: 900, height: 600)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.delegate = self
        window.center()
        self.window = window
        return window
    }
}

struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else {
                return
            }

            MainWindowController.shared.attach(to: window)
        }
    }
}
