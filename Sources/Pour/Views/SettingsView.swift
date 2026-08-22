import DesignKit
import SwiftUI
import TranscriptionKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var availableLocales: [Locale] = []
    @State private var downloadProgress: Double?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PourSpace.xl) {
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
                        Text("Hold this key to dictate, anywhere. Click, then press the key you want.")
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
            Text("A Brewed AI product ·")
                .foregroundStyle(PourColor.textDim)
            Link("brewed-ai.com", destination: URL(string: "https://brewed-ai.com/")!)
                .foregroundStyle(PourColor.blue500)
        }
        .font(PourFont.callout())
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var hotkeyKeyCode: Binding<CGKeyCode> {
        Binding(
            get: { model.settings.hotkeyKeyCode },
            set: { _ in } // HotkeyRecorder reports through onChange; AppModel is the source of truth.
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
