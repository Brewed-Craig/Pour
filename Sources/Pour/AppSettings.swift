import CoreGraphics
import Foundation
import HotkeyKit

/// Persisted user settings: the push-to-talk key and the transcription locale
/// ("the model," in Settings). Everything else about the engine stays exactly as it is.
struct AppSettings: Codable {
    var hotkeyKeyCode: CGKeyCode = 50 // kVK_ANSI_Grave — Pour's original default
    var localeIdentifier: String = Locale.current.identifier

    private static let defaultsKey = "com.brewedai.pour.settings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    var hotkeyConfig: PushToTalkHotkey.Config {
        var config = PushToTalkHotkey.Config()
        config.keyCode = hotkeyKeyCode
        return config
    }
}
