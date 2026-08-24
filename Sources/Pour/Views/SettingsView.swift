import AudioCapture
import AVFoundation
import DesignKit
import HotkeyKit
import SwiftUI
import TranscriptionKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var availableLocales: [Locale] = []
    @State private var availableMicrophones: [MicrophoneDevice] = []
    @State private var downloadProgress: Double?
    @State private var confirmingHistoryClear = false

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

                settingsCard(title: "Privacy") {
                    VStack(alignment: .leading, spacing: PourSpace.sm) {
                        HStack {
                            VStack(alignment: .leading, spacing: PourSpace.xxs) {
                                Text("Enable History")
                                    .font(PourFont.body(13))
                                    .foregroundStyle(PourColor.text)
                                Text("Save transcripts locally for up to five days.")
                                    .font(PourFont.callout())
                                    .foregroundStyle(PourColor.textMuted)
                            }
                            Spacer()
                            Toggle("", isOn: historyEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .tint(PourColor.amber)
                        }
                        Divider().overlay(PourColor.borderHairline)
                        HStack {
                            Text("Delete every saved transcript from this Mac.")
                                .font(PourFont.callout())
                                .foregroundStyle(PourColor.textMuted)
                            Spacer()
                            Button("Clear History", role: .destructive) {
                                confirmingHistoryClear = true
                            }
                            .disabled(model.history.entries.isEmpty)
                        }
                    }
                }

                settingsCard(title: "Microphone") {
                    VStack(alignment: .leading, spacing: PourSpace.sm) {
                        HStack {
                            Text("Input device")
                                .font(PourFont.body(13))
                                .foregroundStyle(PourColor.text)
                            Spacer()
                            Picker("", selection: microphoneDeviceID) {
                                Text("System Default").tag(Optional<String>.none)
                                ForEach(availableMicrophones) { device in
                                    Text(device.name).tag(Optional(device.id))
                                }
                            }
                            .labelsHidden()
                            .frame(minWidth: 200)
                            .tint(PourColor.blue500)
                        }
                        Text("Which mic Pour listens to. Follows the system default unless you pick one here.")
                            .font(PourFont.callout())
                            .foregroundStyle(PourColor.textMuted)
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
                            Text("Engine")
                                .font(PourFont.body(13))
                                .foregroundStyle(PourColor.text)
                            Spacer()
                            Picker("", selection: engineKind) {
                                Text("Apple").tag(EngineKind.apple)
                                Text("Parakeet").tag(EngineKind.parakeet)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 200)
                        }
                        Text(engineHint)
                            .font(PourFont.callout())
                            .foregroundStyle(PourColor.textMuted)

                        Divider().overlay(PourColor.borderHairline)

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
                        .disabled(model.settings.engineKind != .apple)
                        .opacity(model.settings.engineKind == .apple ? 1 : 0.4)

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
        .task { refreshMicrophones() }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in
            refreshMicrophones()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in
            refreshMicrophones()
        }
        .confirmationDialog(
            "Clear all transcription history?",
            isPresented: $confirmingHistoryClear,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                model.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every saved transcript from this Mac.")
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

    private func refreshMicrophones() {
        let devices = MicrophoneCapture.availableDevices()
        // Keep the current selection visible in the list even if it just went
        // offline, so the picker doesn't silently snap back to System Default.
        if let selected = model.settings.microphoneDeviceUniqueID,
           !devices.contains(where: { $0.id == selected }) {
            availableMicrophones = devices + [MicrophoneDevice(id: selected, name: "Unavailable Device")]
        } else {
            availableMicrophones = devices
        }
    }

    private var microphoneDeviceID: Binding<String?> {
        Binding(
            get: { model.settings.microphoneDeviceUniqueID },
            set: { model.setMicrophoneDevice($0) }
        )
    }

    private var historyEnabled: Binding<Bool> {
        Binding(
            get: { model.settings.historyEnabled },
            set: { model.setHistoryEnabled($0) }
        )
    }

    private var engineKind: Binding<EngineKind> {
        Binding(
            get: { model.settings.engineKind },
            set: { newValue in
                Task {
                    downloadProgress = 0
                    await model.setEngineKind(newValue) { fraction in
                        Task { @MainActor in downloadProgress = fraction }
                    }
                    downloadProgress = nil
                }
            }
        )
    }

    private var engineHint: String {
        switch model.settings.engineKind {
        case .apple:
            "Apple's on-device SpeechAnalyzer. Models are managed by macOS."
        case .parakeet:
            "FluidAudio's Parakeet, on-device. Downloads its own model on first use (needs " +
            "network once) and is English-only for now, so the language picker is disabled."
        }
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
