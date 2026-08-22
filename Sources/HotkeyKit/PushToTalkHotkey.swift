import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

public enum HotkeyError: Error, LocalizedError {
    case accessibilityNotTrusted
    case tapCreationFailed

    public var errorDescription: String? {
        switch self {
        case .accessibilityNotTrusted:
            return "Pour needs Accessibility access to see the push-to-talk key."
        case .tapCreationFailed:
            return "Could not create the keyboard event tap."
        }
    }
}

/// Push-to-talk on a held key. Default is backtick (`) — virtual key 50.
///
/// The key-down is swallowed so the character never reaches the app you're typing in.
/// If you let go again within `tapThreshold`, we assume you actually wanted to type a
/// backtick and re-post it synthetically, so the key isn't lost to you forever.
///
/// Modifier combinations (⌘`, ⌃`, ⌥`) pass straight through — those are real shortcuts.
public final class PushToTalkHotkey {

    public struct Config {
        /// kVK_ANSI_Grave.
        public var keyCode: CGKeyCode = 50
        /// Held for less than this and we treat it as "you meant to type the character".
        public var tapThreshold: TimeInterval = 0.22
        /// kVK_Escape — cancels an in-flight dictation.
        public var cancelKeyCode: CGKeyCode = 53

        public init() {}
    }

    /// Fired on the event tap thread (the main run loop). Keep handlers cheap —
    /// if you block here, macOS disables the tap out from under you.
    public var onPress: (() -> Void)?
    public var onRelease: ((TimeInterval) -> Void)?
    public var onCancel: (() -> Void)?

    /// Stamped on events we synthesize, so the tap ignores its own output.
    static let syntheticMarker: Int64 = 0x504F_5552 // "POUR"

    private let config: Config
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var isDown = false
    private var pressedAt: CFAbsoluteTime = 0

    public init(config: Config = Config()) {
        self.config = config
    }

    public var isRunning: Bool { tap != nil }

    public func start() throws {
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else { throw HotkeyError.accessibilityNotTrusted }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: pourEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw HotkeyError.tapCreationFailed
        }

        let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)

        tap = newTap
        source = newSource
    }

    public func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        isDown = false
    }

    // MARK: - Tap callback

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Hazard 01 from the architecture doc: the system disables a tap that blocks
        // for too long, and it does it silently. Re-arm rather than dying.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Never eat keystrokes we generated ourselves.
        if event.getIntegerValueField(.eventSourceUserData) == PushToTalkHotkey.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        // Esc during a dictation discards it, and the app never sees the Esc.
        if isDown, type == .keyDown, code == config.cancelKeyCode {
            isDown = false
            onCancel?()
            return nil
        }

        guard code == config.keyCode else { return Unmanaged.passUnretained(event) }

        let passThroughModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
        if !event.flags.intersection(passThroughModifiers).isEmpty {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            // Swallow auto-repeat; holding the key is the gesture, not a stream of presses.
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
            if !isDown {
                isDown = true
                pressedAt = CFAbsoluteTimeGetCurrent()
                onPress?()
            }
            return nil

        case .keyUp:
            guard isDown else { return nil }
            isDown = false
            let held = CFAbsoluteTimeGetCurrent() - pressedAt
            if held < config.tapThreshold {
                onCancel?()
                postLiteralKey(shift: event.flags.contains(.maskShift))
            } else {
                onRelease?(held)
            }
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    /// Re-emit the character the user actually wanted. Posted asynchronously so we
    /// aren't generating events from inside the tap callback.
    private func postLiteralKey(shift: Bool) {
        let keyCode = config.keyCode
        DispatchQueue.main.async {
            guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
            let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
            let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
            let flags: CGEventFlags = shift ? [.maskShift] : []
            down?.flags = flags
            up?.flags = flags
            down?.setIntegerValueField(.eventSourceUserData, value: PushToTalkHotkey.syntheticMarker)
            up?.setIntegerValueField(.eventSourceUserData, value: PushToTalkHotkey.syntheticMarker)
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}

/// Must stay capture-free — this is bridged to a C function pointer.
private let pourEventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let hotkey = Unmanaged<PushToTalkHotkey>.fromOpaque(refcon).takeUnretainedValue()
    return hotkey.handle(type: type, event: event)
}
