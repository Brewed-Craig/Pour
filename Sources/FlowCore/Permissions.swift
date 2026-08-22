import AVFoundation
import AppKit
import ApplicationServices

public enum Permissions {

    // MARK: - Microphone

    public static var microphoneStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    public static func requestMicrophone() async -> Bool {
        switch microphoneStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    // MARK: - Accessibility

    /// Needed twice over: to create the event tap, and to write text into other apps.
    public static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system's "open System Settings" prompt if not already granted.
    @discardableResult
    public static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    public static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url { NSWorkspace.shared.open(url) }
    }

    public static func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        if let url { NSWorkspace.shared.open(url) }
    }
}
