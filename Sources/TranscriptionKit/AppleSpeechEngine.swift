import AVFoundation
import Foundation
import Speech

/// Transcription on Apple's on-device Speech framework (macOS 26+).
///
/// Uses the `.progressiveTranscription` preset, which turns on volatile results and
/// biases for responsiveness — the right trade for live dictation, where the user is
/// watching text appear and the final pass happens milliseconds after they stop talking.
///
/// Dictation inference is on-device. The OS may use the network to download its managed
/// speech-model asset once per locale on first use; Pour does not upload audio or text.
public final class AppleSpeechEngine: SpeechEngine {

    public static let displayName = "Apple SpeechAnalyzer"

    public enum Failure: Error, LocalizedError {
        case unavailable
        case unsupportedLocale(String)
        case noCompatibleAudioFormat
        case notStarted

        public var errorDescription: String? {
            switch self {
            case .unavailable:
                return "On-device speech transcription isn't available on this Mac."
            case .unsupportedLocale(let id):
                return "Apple's transcriber doesn't support \(id)."
            case .noCompatibleAudioFormat:
                return "No audio format the transcriber accepts is available."
            case .notStarted:
                return "No dictation is in progress."
            }
        }
    }

    public let audioFormat: AVAudioFormat

    private let locale: Locale

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    /// Text from results the transcriber has committed to.
    private var finalized = ""
    /// The current tentative phrase, replaced on every volatile result.
    private var volatile = ""

    /// The Dictionary's vocabulary, applied to the analyzer at the start of the next
    /// utterance. See `updateContext(vocabulary:)`.
    private var pendingVocabulary: [String] = []

    private init(locale: Locale, audioFormat: AVAudioFormat) {
        self.locale = locale
        self.audioFormat = audioFormat
    }

    // MARK: - Setup

    /// The locales Settings' model picker can offer.
    public static func supportedLocales() async -> [Locale] {
        await SpeechTranscriber.supportedLocales.sorted {
            $0.identifier(.bcp47) < $1.identifier(.bcp47)
        }
    }

    /// Resolves a locale, installs its model if needed, and negotiates an audio format.
    /// Call once at launch — the model download can take a while on first run.
    public static func make(
        locale requested: Locale = Locale.current,
        onDownloadProgress: ((Double) -> Void)? = nil
    ) async throws -> AppleSpeechEngine {

        guard SpeechTranscriber.isAvailable else { throw Failure.unavailable }

        let supported = await SpeechTranscriber.supportedLocales
        let wanted = requested.identifier(.bcp47)
        let resolved = supported.first { $0.identifier(.bcp47) == wanted }
            ?? supported.first { $0.language.languageCode == requested.language.languageCode }
        guard let locale = resolved else {
            throw Failure.unsupportedLocale(requested.identifier)
        }

        // Only one locale can be reserved at a time; clear whatever a previous run left.
        for reserved in await AssetInventory.reservedLocales {
            await AssetInventory.release(reservedLocale: reserved)
        }
        try await AssetInventory.reserve(locale: locale)

        let probe = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)

        let installed = await SpeechTranscriber.installedLocales
        let isInstalled = installed.contains { $0.identifier(.bcp47) == locale.identifier(.bcp47) }
        if !isInstalled,
           let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
            let progress = request.progress
            let reporter = Task {
                while !Task.isCancelled, !progress.isFinished {
                    onDownloadProgress?(progress.fractionCompleted)
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            try await request.downloadAndInstall()
            reporter.cancel()
            onDownloadProgress?(1.0)
        }

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [probe]) else {
            throw Failure.noCompatibleAudioFormat
        }

        return AppleSpeechEngine(locale: locale, audioFormat: format)
    }

    // MARK: - Utterance lifecycle

    public func beginUtterance(onUpdate: @escaping (TranscriptionUpdate) -> Void) async throws {
        await cancelUtterance()

        finalized = ""
        volatile = ""

        // A fresh analyzer per utterance. Modules share backing engines and models when
        // they're configured alike, so this is cheaper than it looks — and it keeps one
        // bad utterance from poisoning the next.
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)

        self.transcriber = transcriber
        self.analyzer = analyzer
        self.continuation = continuation

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }
                    let piece = String(result.text.characters)
                    if result.isFinal {
                        self.finalized += piece
                        self.volatile = ""
                    } else {
                        self.volatile = piece
                    }
                    onUpdate(TranscriptionUpdate(text: self.finalized + self.volatile, isFinal: false))
                }
            } catch {
                // The analyzer finishes its result stream on error; endUtterance()
                // will return whatever we managed to accumulate.
            }
        }

        try await analyzer.start(inputSequence: stream)

        // Best-effort — as of this writing Apple's own engineers confirm SpeechTranscriber
        // doesn't act on contextual strings (only DictationTranscriber does). Wired anyway:
        // it's free, and it starts working the moment Apple extends support.
        if !pendingVocabulary.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = pendingVocabulary
            try? await analyzer.setContext(context)
        }
    }

    public func updateContext(vocabulary: [String]) async {
        pendingVocabulary = vocabulary
    }

    public func feed(_ buffer: AVAudioPCMBuffer) {
        continuation?.yield(AnalyzerInput(buffer: buffer))
    }

    public func endUtterance() async throws -> String {
        guard let analyzer else { throw Failure.notStarted }

        continuation?.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        await resultsTask?.value

        let text = (finalized + volatile).trimmingCharacters(in: .whitespacesAndNewlines)
        teardown()
        return text
    }

    public func cancelUtterance() async {
        guard analyzer != nil else { return }
        continuation?.finish()
        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }
        resultsTask?.cancel()
        teardown()
    }

    private func teardown() {
        resultsTask = nil
        continuation = nil
        analyzer = nil
        transcriber = nil
    }
}
