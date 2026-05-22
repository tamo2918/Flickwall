import Combine
import Foundation

@MainActor
final class ShortcutStore: ObservableObject {
    @Published private(set) var shortcut: HotKeyShortcut {
        didSet {
            save()
        }
    }

    private let defaults: UserDefaults
    private let key = "switcherShortcut.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(HotKeyShortcut.self, from: data) {
            self.shortcut = decoded == .legacyDefaultValue ? .defaultValue : decoded
        } else {
            self.shortcut = .defaultValue
        }
    }

    func setShortcut(_ shortcut: HotKeyShortcut) {
        self.shortcut = shortcut
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(shortcut) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
