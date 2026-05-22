import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private weak var window: NSWindow?

    func attach(to window: NSWindow) {
        guard self.window !== window else {
            return
        }

        self.window = window
        window.isReleasedWhenClosed = false
        window.delegate = self
    }

    func showWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)

        guard let window else {
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
