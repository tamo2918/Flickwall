import AppKit
import Carbon
import SwiftUI

@MainActor
final class WallpaperOverlayController {
    private let store: WallpaperStore
    private let onApply: () -> Void
    private let onCancel: () -> Void
    private var panel: WallpaperOverlayPanel?
    private var previousFrontmostApplication: NSRunningApplication?
    private var shortcutRelease: HotKeyShortcut?
    private var localReleaseMonitor: Any?
    private var globalReleaseMonitor: Any?
    private var isCompletingShortcutRelease = false

    init(store: WallpaperStore, onApply: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.store = store
        self.onApply = onApply
        self.onCancel = onCancel
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(applyOnShortcutRelease shortcut: HotKeyShortcut? = nil) {
        guard !store.wallpapers.isEmpty else {
            return
        }

        let panel = panel ?? makePanel()
        self.panel = panel

        if !panel.isVisible {
            captureFrontmostApplication()
        }

        position(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        if let shortcut {
            startShortcutReleaseMonitoring(for: shortcut)
        }
    }

    func hide() {
        stopShortcutReleaseMonitoring()
        panel?.orderOut(nil)
        restoreFrontmostApplication()
    }

    private func makePanel() -> WallpaperOverlayPanel {
        let panel = WallpaperOverlayPanel()
        panel.actionHandler = { [weak self] action in
            self?.handle(action)
        }
        panel.contentView = NSHostingView(rootView: WallpaperSwitcherOverlay(store: store))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        return panel
    }

    private func handle(_ action: WallpaperOverlayPanel.Action) {
        switch action {
        case .next:
            store.selectNext()
        case .previous:
            store.selectPrevious()
        case .apply:
            onApply()
        case .cancel:
            onCancel()
        }
    }

    private func position(_ panel: NSPanel) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let maxWidth = max(320, visibleFrame.width - 80)
        let naturalWidth = CGFloat(store.wallpapers.count) * 154 + 96
        let width = min(max(540, naturalWidth), min(960, maxWidth))
        let height: CGFloat = 260

        let frame = NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )

        panel.setFrame(frame, display: true)
    }

    private func captureFrontmostApplication() {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        if frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            previousFrontmostApplication = nil
        } else {
            previousFrontmostApplication = frontmostApplication
        }
    }

    private func restoreFrontmostApplication() {
        previousFrontmostApplication?.activate(options: [])
        previousFrontmostApplication = nil
    }

    private func startShortcutReleaseMonitoring(for shortcut: HotKeyShortcut) {
        stopShortcutReleaseMonitoring()
        shortcutRelease = shortcut

        localReleaseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyUp]) { [weak self] event in
            self?.handleShortcutReleaseEvent(event)
            return event
        }

        globalReleaseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleShortcutReleaseEvent(event)
            }
        }
    }

    private func stopShortcutReleaseMonitoring() {
        if let localReleaseMonitor {
            NSEvent.removeMonitor(localReleaseMonitor)
            self.localReleaseMonitor = nil
        }

        if let globalReleaseMonitor {
            NSEvent.removeMonitor(globalReleaseMonitor)
            self.globalReleaseMonitor = nil
        }

        shortcutRelease = nil
        isCompletingShortcutRelease = false
    }

    private func handleShortcutReleaseEvent(_ event: NSEvent) {
        guard let shortcutRelease, !isCompletingShortcutRelease else {
            return
        }

        let currentFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredFlags = shortcutRelease.eventModifiers
        let didReleaseMainKey = event.type == .keyUp && event.keyCode == shortcutRelease.keyCode
        let didReleaseModifier = currentFlags.intersection(requiredFlags) != requiredFlags

        guard didReleaseMainKey || didReleaseModifier else {
            return
        }

        completeShortcutRelease()
    }

    private func completeShortcutRelease() {
        guard !isCompletingShortcutRelease else {
            return
        }

        isCompletingShortcutRelease = true
        stopShortcutReleaseMonitoring()
        onApply()
    }
}

final class WallpaperOverlayPanel: NSPanel {
    enum Action {
        case next
        case previous
        case apply
        case cancel
    }

    var actionHandler: ((Action) -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case UInt16(kVK_Tab), UInt16(kVK_RightArrow), UInt16(kVK_DownArrow):
            if event.modifierFlags.contains(.shift) {
                actionHandler?(.previous)
            } else {
                actionHandler?(.next)
            }
        case UInt16(kVK_LeftArrow), UInt16(kVK_UpArrow):
            actionHandler?(.previous)
        case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter), UInt16(kVK_Space):
            return
        case UInt16(kVK_Escape):
            actionHandler?(.cancel)
        default:
            super.keyDown(with: event)
        }
    }
}
