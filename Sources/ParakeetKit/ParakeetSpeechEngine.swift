import AVFoundation
import FluidAudio
import Foundation
import TranscriptionKit

/// Transcription via FluidAudio's streaming Parakeet EOU model — fully on-device, same
/// as Apple's engine, but downloads its own CoreML models from Hugging Face on first
/// use since there's no OS-managed asset story for third-party models the way
/// `AssetInventory` gives Apple's engine.
///
/// Bridges `StreamingEouAsrManager` (an actor, all-async) into `SpeechEngine`'s
/// synchronous, audio-thread-safe `feed(_:)` the same way `AppleSpeechEngine` bridges
/// `SpeechAnalyzer`: buffers queue into an `AsyncStream`, and a background task drains
/// it into the actor.
public final class ParakeetSpeechEngine: SpeechEngine {

    public static let displayName = "Parakeet (FluidAudio)"

    public enum Failure: Error, LocalizedError {
        case noCompatibleAudioFormat

        public var errorDescription: String? {
            switch self {
            case .noCompatibleAudioFormat:
                return "Could not negotiate an audio format for the Parakeet engine."
            }
        }
    }

    public let audioFormat: AVAudioFormat

    private let manager: StreamingEouAsrManager
    private var continuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var pumpTask: Task<Void, Never>?

    private init(manager: StreamingEouAsrManager, audioFormat: AVAudioFormat) {
        self.manager = manager
        self.audioFormat = audioFormat
    }

    // MARK: - Setup

    /// Downloads (first run only, cached after) and loads the Parakeet EOU streaming
    /// model. 160ms chunks — FluidAudio's best-tested, lowest-latency configuration.
    public static func make(onDownloadProgress: ((Double) -> Void)? = nil) async throws -> ParakeetSpeechEngine {
        let manager = StreamingEouAsrManager(chunkSize: .ms160)
        try await manager.loadModels(to: nil, configuration: nil) { progress in
            onDownloadProgress?(progress.fractionCompleted)
        }

        // FluidAudio resamples internally regardless of what it's fed, but
        // `MicrophoneCapture`'s tap still needs a concrete PCM format to convert into
        // before feeding — 16kHz mono float32 is what the model actually wants.
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false
        ) else {
            throw Failure.noCompatibleAudioFormat
        }

        return ParakeetSpeechEngine(manager: manager, audioFormat: format)
    }

    // MARK: - Utterance lifecycle

    public func beginUtterance(onUpdate: @escaping (TranscriptionUpdate) -> Void) async throws {
        await cancelUtterance()

        await manager.reset()
        await manager.setPartialTranscriptCallback { text in
            onUpdate(TranscriptionUpdate(text: text, isFinal: false))
        }

        let (stream, continuation) = AsyncStream.makeStream(of: AVAudioPCMBuffer.self)
        self.continuation = continuation

        let manager = self.manager
        pumpTask = Task {
            for await buffer in stream {
                try? await manager.appendAudio(buffer)
                try? await manager.processBufferedAudio()
            }
        }
    }

    public func feed(_ buffer: AVAudioPCMBuffer) {
        continuation?.yield(buffer)
    }

    public func endUtterance() async throws -> String {
        continuation?.finish()
        await pumpTask?.value
        teardown()
        let text = try await manager.finish()
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func cancelUtterance() async {
        guard continuation != nil || pumpTask != nil else { return }
        continuation?.finish()
        await pumpTask?.value
        teardown()
        await manager.reset()
    }

    private func teardown() {
        continuation = nil
        pumpTask = nil
    }
}
