import DesignKit
import HotkeyKit
import SwiftUI
import TranscriptionKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var availableLocales: [Locale] = []
    @State private var downloadProgress: Double?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PourSpace.xl) {
                settingsCard(title: "General") {
                    HStack {
                        Text("Launch at login")
                            .font(PourFont.body(13))
                            .foregroundStyle(PourColor.text)
                        Spacer()
                        Toggle("", isOn: launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(PourColor.amber)
                    }
                }

                settingsCard(title: "Hotkey") {
                    VStack(alignment: .leading, spacing: PourSpace.sm) {
                        HStack {
                            Text("Push-to-talk key")
                                .font(PourFont.body(13))
                                .foregroundStyle(PourColor.text)
                            Spacer()
                            HotkeyRecorder(keyCode: hotkeyKeyCode) { newCode in
                                var config = model.settings.hotkeyConfig
                                config.keyCode = newCode
                                model.setHotkey(config)
                            }
                        }
                        Divider().overlay(PourColor.borderHairline)
                        HStack {
                            Text("Style")
                                .font(PourFont.body(13))
                                .foregroundStyle(PourColor.text)
                            Spacer()
                            Picker("", selection: interactionMode) {
                                Text("Hold to talk").tag(PushToTalkHotkey.InteractionMode.holdToTalk)
                                Text("Press to start/stop").tag(PushToTalkHotkey.InteractionMode.toggle)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 260)
                        }
                        Text(interactionModeHint)
                            .font(PourFont.callout())
                            .foregroundStyle(PourColor.textMuted)
                    }
                }

                settingsCard(title: "Model") {
                    VStack(alignment: .leading, spacing: PourSpace.md) {
                        HStack {
                            Text("Language")
                                .font(PourFont.body(13))
                                .foregroundStyle(PourColor.text)
                            Spacer()
                            Picker("", selection: localeIdentifier) {
                                ForEach(availableLocales, id: \.identifier) { locale in
                                    Text(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
                                        .tag(locale.identifier)
                                }
                            }
                            .labelsHidden()
                            .frame(minWidth: 200)
                            .tint(PourColor.blue500)
                        }
                        Divider().overlay(PourColor.borderHairline)
                        HStack {
                            Text("Engine")
                                .font(PourFont.body(13))
                                .foregroundStyle(PourColor.text)
                            Spacer()
                            Text(AppleSpeechEngine.displayName)
                                .font(PourFont.mono(12))
                                .foregroundStyle(PourColor.textMuted)
                        }
                        if let downloadProgress {
                            ProgressView(value: downloadProgress)
                                .tint(PourColor.amber)
                            Text("Downloading speech model\u{2026} \(Int(downloadProgress * 100))%")
                                .font(PourFont.callout())
                                .foregroundStyle(PourColor.textMuted)
                        }
                    }
                }

                footer
            }
            .padding(PourSpace.lg)
            .frame(maxWidth: 480, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("Settings")
        .task {
            availableLocales = await AppleSpeechEngine.supportedLocales()
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PourSpace.sm) {
            Text(title.uppercased())
                .font(PourFont.caption())
                .foregroundStyle(PourColor.textDim)
            content()
        }
        .pourCard(padding: PourSpace.lg)
    }

    private var footer: some View {
        HStack(spacing: PourSpace.xxs) {
            Text("A Brewed AI passion project ·")
                .foregroundStyle(PourColor.textDim)
            Link("brewed-ai.com", destination: URL(string: "https://brewed-ai.com/")!)
                .foregroundStyle(PourColor.blue500)
        }
        .font(PourFont.callout())
    }

    private var hotkeyKeyCode: Binding<CGKeyCode> {
        Binding(
            get: { model.settings.hotkeyKeyCode },
            set: { _ in } // HotkeyRecorder reports through onChange; AppModel is the source of truth.
        )
    }

    private var interactionMode: Binding<PushToTalkHotkey.InteractionMode> {
        Binding(
            get: { model.settings.interactionMode },
            set: { model.setInteractionMode($0) }
        )
    }

    private var interactionModeHint: String {
        switch model.settings.interactionMode {
        case .holdToTalk:
            "Hold this key to dictate, anywhere. Click, then press the key you want. Let go to finish."
        case .toggle:
            "Press once to start dictating, press again to stop. Esc still cancels."
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { model.settings.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        )
    }

    private var localeIdentifier: Binding<String> {
        Binding(
            get: { model.settings.localeIdentifier },
            set: { newValue in
                Task {
                    downloadProgress = 0
                    await model.setLocale(newValue) { fraction in
                        Task { @MainActor in downloadProgress = fraction }
                    }
                    downloadProgress = nil
                }
            }
        )
    }
}
