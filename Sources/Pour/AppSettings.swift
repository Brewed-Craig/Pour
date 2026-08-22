import CoreGraphics
import Foundation
import HotkeyKit

/// Which `SpeechEngine` Settings' Model picker points `DictationController` at.
/// Apple's SpeechAnalyzer is the default and always available; Parakeet is optional
/// (downloads its own models on first use — see `ParakeetKit`).
enum EngineKind: String, Codable {
    case apple
    case parakeet
}

/// Persisted user settings: the push-to-talk key and its interaction mode, and the
/// transcription engine/locale ("the model," in Settings).
struct AppSettings: Codable {
    var hotkeyKeyCode: CGKeyCode = 50 // kVK_ANSI_Grave — Pour's original default
    var interactionMode: PushToTalkHotkey.InteractionMode = .holdToTalk
    var engineKind: EngineKind = .apple
    var localeIdentifier: String = Locale.current.identifier
    var launchAtLogin: Bool = false
    var historyEnabled: Bool = true

    init() {}

    // Custom decoding with per-field fallbacks: a field added after some users
    // already have a saved settings file must not make the whole decode fail and
    // silently reset their hotkey and locale back to defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotkeyKeyCode = try c.decodeIfPresent(CGKeyCode.self, forKey: .hotkeyKeyCode) ?? 50
        interactionMode = try c.decodeIfPresent(PushToTalkHotkey.InteractionMode.self, forKey: .interactionMode) ?? .holdToTalk
        engineKind = try c.decodeIfPresent(EngineKind.self, forKey: .engineKind) ?? .apple
        localeIdentifier = try c.decodeIfPresent(String.self, forKey: .localeIdentifier) ?? Locale.current.identifier
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        historyEnabled = try c.decodeIfPresent(Bool.self, forKey: .historyEnabled) ?? true
    }

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
        config.mode = interactionMode
        return config
    }
}
