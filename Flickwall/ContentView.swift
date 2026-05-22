//
//  ContentView.swift
//  Flickwall
//
//  Created by Tatsuki Morita on 2026/05/22.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WallpaperStore
    @ObservedObject var coordinator: AppCoordinator

    @State private var selectedSection: SidebarSection = .all

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("Library") {
                    ForEach(SidebarSection.librarySections) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }

                Section("App") {
                    Label(SidebarSection.settings.title, systemImage: SidebarSection.settings.systemImage)
                        .tag(SidebarSection.settings)
                }
            }
            .navigationTitle("Flickwall")
            .listStyle(.sidebar)
        } detail: {
            switch selectedSection {
            case .all, .favorites, .recent:
                WallpaperLibraryView(
                    title: selectedSection.title,
                    items: filteredItems,
                    store: store,
                    coordinator: coordinator
                )
            case .settings:
                ShortcutSettingsView(
                    shortcutStore: coordinator.shortcutStore,
                    coordinator: coordinator
                )
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    coordinator.addImages()
                } label: {
                    Label("Add Images", systemImage: "photo.badge.plus")
                }

                Button {
                    coordinator.addFolder()
                } label: {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }

                Divider()

                Button {
                    coordinator.showSwitcher()
                } label: {
                    Label("Show Switcher", systemImage: "rectangle.stack")
                }

                Button {
                    coordinator.applySelected()
                } label: {
                    Label("Apply", systemImage: "checkmark.circle")
                }
                .disabled(store.selectedWallpaper == nil)
            }
        }
        .alert("Flickwall", isPresented: errorIsPresented) {
            Button("OK") {
                coordinator.clearError()
            }
        } message: {
            Text(coordinator.lastError ?? "")
        }
    }

    private var filteredItems: [WallpaperItem] {
        switch selectedSection {
        case .all:
            return store.wallpapers
        case .favorites:
            return store.favoriteWallpapers
        case .recent:
            return store.recentWallpapers
        case .settings:
            return []
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { coordinator.lastError != nil },
            set: { isPresented in
                if !isPresented {
                    coordinator.clearError()
                }
            }
        )
    }
}

private enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case all
    case favorites
    case recent
    case settings

    var id: Self { self }

    static var librarySections: [SidebarSection] {
        [.all, .favorites, .recent]
    }

    var title: String {
        switch self {
        case .all:
            return "All Wallpapers"
        case .favorites:
            return "Favorites"
        case .recent:
            return "Recent"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "photo.on.rectangle.angled"
        case .favorites:
            return "star"
        case .recent:
            return "clock.arrow.circlepath"
        case .settings:
            return "gearshape"
        }
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "FlickwallPreview") ?? .standard
    let store = WallpaperStore(defaults: defaults)
    let shortcutStore = ShortcutStore(defaults: defaults)
    ContentView(store: store, coordinator: AppCoordinator(store: store, shortcutStore: shortcutStore))
}
