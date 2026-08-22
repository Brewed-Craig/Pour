import AVFoundation
import Foundation

/// One transcription update. `text` is always the full utterance so far, not a delta —
/// callers render it directly and don't have to reassemble anything.
public struct TranscriptionUpdate: Sendable {
    public let text: String
    public let isFinal: Bool

    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}

/// The seam that lets Apple's SpeechAnalyzer, Parakeet, and WhisperKit be
/// interchangeable. Nothing above this protocol should know which one is running.
///
/// Lifecycle per dictation: `beginUtterance` → many `feed` → `endUtterance` (or
/// `cancelUtterance`). An engine is reusable across utterances.
public protocol SpeechEngine: AnyObject {

    /// Shown in Settings.
    static var displayName: String { get }

    /// The PCM format this engine wants. Feed it nothing else.
    var audioFormat: AVAudioFormat { get }

    /// Open a new utterance. `onUpdate` may be called on any thread.
    func beginUtterance(onUpdate: @escaping (TranscriptionUpdate) -> Void) async throws

    /// Push converted audio. Must be cheap and non-blocking — this is the audio thread.
    func feed(_ buffer: AVAudioPCMBuffer)

    /// Close the utterance and return the finalized transcript.
    func endUtterance() async throws -> String

    /// Throw the utterance away without finalizing.
    func cancelUtterance() async

    /// Best-effort vocabulary bias for the *next* utterance — the Dictionary's terms,
    /// kept short. Default no-op: most engines, and older OS versions, have nothing to
    /// do here. This is a nudge, never a guarantee — callers still need a correction
    /// pass after transcribing.
    func updateContext(vocabulary: [String]) async
}

extension SpeechEngine {
    public func updateContext(vocabulary: [String]) async {}
}
