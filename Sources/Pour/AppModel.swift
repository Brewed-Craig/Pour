import DictionaryKit
import FlowCore
import Foundation
import HotkeyKit
import Observation

/// The app's central state: the two persisted stores, the dictation controller, and
/// settings. One instance, owned by the app delegate, handed down through the
/// environment to every window.
@MainActor
@Observable
final class AppModel {

    let dictionary = DictionaryStore()
    let history = HistoryStore()
    let controller: DictationController
    private(set) var settings: AppSettings

    /// The main window's sidebar selection — lives here, not as local view state, so
    /// the menu bar's "Settings…" can jump to it from outside the window entirely.
    var selectedSidebarSection: SidebarSection? = .transcriptions

    /// Mirrors of the controller's callback-based state, so SwiftUI views can read
    /// them directly. `DictationController` only supports one subscriber per signal —
    /// this is that one subscriber; everyone else (the menu bar item, the HUD) adds an
    /// observer below instead of touching the controller directly.
    private(set) var dictationState: DictationState = .starting
    private(set) var preview: String = ""
    private(set) var level: Float = 0

    private var stateObservers: [(DictationState) -> Void] = []
    private var previewObservers: [(String) -> Void] = []
    /// Fired right after a `HistoryEntry` lands, for the menu bar's "last transcript" line.
    var onDeliveredEntry: ((HistoryEntry) -> Void)?
    /// Fired whenever settings change — the menu bar's "hold ` to dictate" hint needs
    /// to track the current hotkey, not the one it was launched with.
    var onSettingsChanged: ((AppSettings) -> Void)?

    init() {
        let loaded = AppSettings.load()
        settings = loaded
        controller = DictationController(
            dictionary: dictionary,
            hotkeyConfig: loaded.hotkeyConfig,
            locale: Locale(identifier: loaded.localeIdentifier)
        )

        controller.onStateChange = { [weak self] state in
            guard let self else { return }
            self.dictationState = state
            for observe in self.stateObservers { observe(state) }
        }
        controller.onPreviewChange = { [weak self] text in
            guard let self else { return }
            self.preview = text
            for observe in self.previewObservers { observe(text) }
        }
        controller.onLevelChange = { [weak self] level in
            self?.level = level
        }
        controller.onDelivered = { [weak self] text, appName, strategy, elapsed, hits in
            guard let self else { return }
            let entry = self.history.record(
                text: text,
                appName: appName,
                strategy: strategy.rawValue,
                elapsedMS: Int((elapsed * 1000).rounded()),
                hits: hits
            )
            self.onDeliveredEntry?(entry)
        }
    }

    func addStateObserver(_ observe: @escaping (DictationState) -> Void) {
        stateObservers.append(observe)
    }

    func addPreviewObserver(_ observe: @escaping (String) -> Void) {
        previewObservers.append(observe)
    }

    func bootstrap(onDownloadProgress: ((Double) -> Void)? = nil) async {
        await controller.start(onDownloadProgress: onDownloadProgress)
    }

    func setHotkey(_ config: PushToTalkHotkey.Config) {
        settings.hotkeyKeyCode = config.keyCode
        settings.save()
        controller.updateHotkey(config)
        onSettingsChanged?(settings)
    }

    func setLocale(_ identifier: String, onDownloadProgress: ((Double) -> Void)? = nil) async {
        settings.localeIdentifier = identifier
        settings.save()
        await controller.updateLocale(Locale(identifier: identifier), onDownloadProgress: onDownloadProgress)
    }
}
