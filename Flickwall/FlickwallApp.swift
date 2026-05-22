//
//  FlickwallApp.swift
//  Flickwall
//
//  Created by Tatsuki Morita on 2026/05/22.
//

import SwiftUI
import AppKit

@main
@MainActor
struct FlickwallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var store: WallpaperStore
    @StateObject private var shortcutStore: ShortcutStore
    @StateObject private var coordinator: AppCoordinator

    init() {
        let store = WallpaperStore()
        let shortcutStore = ShortcutStore()
        let coordinator = AppCoordinator(store: store, shortcutStore: shortcutStore)

        MainWindowController.shared.configure(store: store, coordinator: coordinator)
        coordinator.openMainWindow = {
            MainWindowController.shared.showWindow()
        }
        coordinator.start()

        _store = StateObject(wrappedValue: store)
        _shortcutStore = StateObject(wrappedValue: shortcutStore)
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        WindowGroup("Flickwall", id: "main") {
            ContentView(store: store, coordinator: coordinator)
                .frame(minWidth: 900, minHeight: 600)
                .background(MainWindowAccessor())
        }
        .defaultLaunchBehavior(.suppressed)
        .commands {
            CommandMenu("Wallpapers") {
                Button("Add Images...") {
                    coordinator.addImages()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Add Folder...") {
                    coordinator.addFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Show Switcher (\(shortcutStore.shortcut.displayText))") {
                    coordinator.showSwitcher()
                }

                Button("Apply Selected Wallpaper") {
                    coordinator.applySelected()
                }
            }
        }
    }
}
