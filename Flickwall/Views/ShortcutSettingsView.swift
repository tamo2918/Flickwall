import AppKit
import Carbon
import SwiftUI

struct ShortcutSettingsView: View {
    @ObservedObject var shortcutStore: ShortcutStore
    @ObservedObject var coordinator: AppCoordinator

    @State private var isRecording = false

    var body: some View {
        Form {
            Section("Keyboard") {
                LabeledContent("Switcher") {
                    ShortcutRecorderButton(
                        shortcut: shortcutStore.shortcut,
                        isRecording: $isRecording,
                        onRecord: coordinator.updateShortcut
                    )
                }

                Button("Reset") {
                    coordinator.updateShortcut(.defaultValue)
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .navigationTitle("Settings")
    }
}

private struct ShortcutRecorderButton: View {
    let shortcut: HotKeyShortcut
    @Binding var isRecording: Bool
    let onRecord: (HotKeyShortcut) -> Void

    var body: some View {
        Button {
            isRecording = true
        } label: {
            Text(isRecording ? "Press Shortcut" : shortcut.displayText)
                .monospaced()
                .frame(minWidth: 140)
        }
        .background(
            ShortcutCaptureView(isRecording: $isRecording, onRecord: onRecord)
                .frame(width: 0, height: 0)
        )
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (HotKeyShortcut) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(
            isRecording: isRecording,
            recording: $isRecording,
            onRecord: onRecord
        )
    }

    final class Coordinator {
        private var monitor: Any?
        private var recording: Binding<Bool>?
        private var onRecord: ((HotKeyShortcut) -> Void)?

        deinit {
            stop()
        }

        func update(
            isRecording: Bool,
            recording: Binding<Bool>,
            onRecord: @escaping (HotKeyShortcut) -> Void
        ) {
            self.recording = recording
            self.onRecord = onRecord

            if isRecording {
                start()
            } else {
                stop()
            }
        }

        private func start() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                self?.handle(event)
                return nil
            }
        }

        private func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func handle(_ event: NSEvent) {
            defer {
                recording?.wrappedValue = false
            }

            guard event.keyCode != UInt16(kVK_Escape) else {
                return
            }

            guard let shortcut = HotKeyShortcut(event: event) else {
                NSSound.beep()
                return
            }

            onRecord?(shortcut)
        }
    }
}
