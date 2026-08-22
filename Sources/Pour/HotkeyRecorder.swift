import AppKit
import CoreGraphics
import DesignKit
import SwiftUI

/// Human-readable names for the keys people actually pick as a push-to-talk key.
/// Falls back to "Key <code>" for anything else — still usable, just less pretty.
enum KeyName {
    private static let names: [CGKeyCode: String] = [
        50: "`", 49: "Space", 53: "Esc", 48: "Tab",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15",
        60: "Right Shift", 56: "Shift", 59: "Control", 62: "Right Control",
        58: "Option", 61: "Right Option", 55: "Command", 54: "Right Command",
        63: "Fn", 36: "Return",
    ]

    static func string(for code: CGKeyCode) -> String {
        names[code] ?? "Key \(code)"
    }
}

/// Click, then press a key. Captures the next key-down via a local event monitor and
/// hands the keycode back — the same `CGKeyCode` `PushToTalkHotkey.Config` expects.
struct HotkeyRecorder: View {
    @Binding var keyCode: CGKeyCode
    var onChange: (CGKeyCode) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(isRecording ? "Press a key\u{2026}" : KeyName.string(for: keyCode))
                .font(PourFont.mono(12.5))
                .frame(minWidth: 110)
        }
        .buttonStyle(isRecording ? AnyButtonStyle(.pourPrimary) : AnyButtonStyle(.pourSecondary))
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let code = CGKeyCode(event.keyCode)
            keyCode = code
            onChange(code)
            stopRecording()
            return nil // swallow it — this keystroke is the binding, not input
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

/// Type-erasing wrapper so the same button can switch between two `ButtonStyle`s.
private struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}
