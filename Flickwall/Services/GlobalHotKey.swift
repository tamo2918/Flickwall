import Carbon
import Foundation

let flickwallHotKeyNotification = Notification.Name("FlickwallGlobalHotKeyPressed")

private let flickwallHotKeySignature = OSType(0x46574C4C)
private let flickwallHotKeyIdentifier = UInt32(1)

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let shortcut: HotKeyShortcut

    init(shortcut: HotKeyShortcut) throws {
        self.shortcut = shortcut
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            globalHotKeyHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            throw GlobalHotKeyError.installFailed(installStatus)
        }

        let hotKeyID = EventHotKeyID(signature: flickwallHotKeySignature, id: flickwallHotKeyIdentifier)
        let registrationStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registrationStatus == noErr else {
            unregister()
            throw GlobalHotKeyError.registrationFailed(registrationStatus)
        }
    }

    deinit {
        unregister()
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}

private let globalHotKeyHandler: EventHandlerUPP = { _, event, _ in
    guard let event else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if status == noErr,
       hotKeyID.signature == flickwallHotKeySignature,
       hotKeyID.id == flickwallHotKeyIdentifier {
        NotificationCenter.default.post(name: flickwallHotKeyNotification, object: nil)
    }

    return noErr
}

enum GlobalHotKeyError: LocalizedError {
    case installFailed(OSStatus)
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .installFailed(let status):
            return "Could not install the global shortcut handler. OSStatus \(status)."
        case .registrationFailed(let status):
            return "Could not register shortcut. OSStatus \(status)."
        }
    }
}
