import AppKit
import Carbon

struct HotKeyShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let defaultValue = HotKeyShortcut(
        keyCode: UInt32(kVK_ANSI_W),
        carbonModifiers: UInt32(cmdKey | optionKey)
    )

    static let legacyDefaultValue = HotKeyShortcut(
        keyCode: UInt32(kVK_ANSI_W),
        carbonModifiers: UInt32(cmdKey | optionKey | controlKey)
    )

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init?(event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        guard keyCode != UInt32(kVK_Escape) else {
            return nil
        }

        let carbonModifiers = Self.carbonModifiers(from: event.modifierFlags)
        guard carbonModifiers != 0 else {
            return nil
        }

        self.init(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }

    var eventModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []

        if carbonModifiers & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }

        if carbonModifiers & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }

        if carbonModifiers & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }

        if carbonModifiers & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }

        return flags
    }

    var displayText: String {
        "\(modifierDisplay)\(keyDisplay)"
    }

    private var modifierDisplay: String {
        var display = ""

        if carbonModifiers & UInt32(controlKey) != 0 {
            display += "⌃"
        }

        if carbonModifiers & UInt32(optionKey) != 0 {
            display += "⌥"
        }

        if carbonModifiers & UInt32(shiftKey) != 0 {
            display += "⇧"
        }

        if carbonModifiers & UInt32(cmdKey) != 0 {
            display += "⌘"
        }

        return display
    }

    private var keyDisplay: String {
        Self.keyDisplays[keyCode] ?? "Key \(keyCode)"
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0

        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }

        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        return modifiers
    }

    private static let keyDisplays: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A",
        UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G",
        UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M",
        UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q",
        UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S",
        UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W",
        UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "Return",
        UInt32(kVK_ANSI_KeypadEnter): "Enter",
        UInt32(kVK_Delete): "Delete",
        UInt32(kVK_ForwardDelete): "Forward Delete",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12"
    ]
}
