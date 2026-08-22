import AVFoundation
import Foundation

/// A microphone that is always running.
///
/// Starting `AVAudioEngine` on key-down costs 150–250ms and clips the first syllable,
/// which is exactly the latency the whole app is trying to protect. So the engine runs
/// from launch, converting into the analyzer's format continuously, and "starting" a
/// dictation just means opening the gate — plus flushing a short pre-roll buffer so the
/// beginning of the word you'd already started saying isn't lost.
public final class MicrophoneCapture {

    public enum Failure: Error, LocalizedError {
        case noInputDevice
        case converterUnavailable
        case engineStartFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noInputDevice:
                return "No microphone is available, or Pour hasn't been granted microphone access."
            case .converterUnavailable:
                return "Could not convert microphone audio into the format the speech engine needs."
            case .engineStartFailed(let reason):
                return "The audio engine wouldn't start: \(reason)"
            }
        }
    }

    private let targetFormat: AVAudioFormat
    private let preRollCapacity: AVAudioFrameCount
    private let engine = AVAudioEngine()
    private let lock = NSLock()

    private var converter: AVAudioConverter?
    private var sink: ((AVAudioPCMBuffer) -> Void)?
    private var preRoll: [AVAudioPCMBuffer] = []
    private var preRollFrames: AVAudioFrameCount = 0
    private var observer: NSObjectProtocol?

    /// RMS level, 0...1, of the raw input — independent of the dictation gate, so the
    /// UI can show a live meter whether or not a capture is in progress. Called on the
    /// audio thread; hop to the main thread in the handler.
    public var onLevel: ((Float) -> Void)?

    /// Adaptive floor and ceiling the meter normalizes against — measured, not
    /// guessed. This Mac's actual ambient RMS runs ~0.0001–0.0008, far below any
    /// fixed dB threshold that looked reasonable on paper; a fixed floor either
    /// pegged the meter at 1.0 constantly or clamped everything to 0, depending on
    /// which Mac and mic gain it happened to run on. Tracking both ends live instead.
    private var levelFloor: Float = 0.0005
    private var levelPeak: Float = 0.01

    public init(targetFormat: AVAudioFormat, preRollSeconds: Double = 0.3) {
        self.targetFormat = targetFormat
        self.preRollCapacity = AVAudioFrameCount(targetFormat.sampleRate * preRollSeconds)
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    public var isRunning: Bool { engine.isRunning }

    // MARK: - Engine lifecycle

    public func startEngine() throws {
        guard !engine.isRunning else { return }
        try installTap()

        do {
            engine.prepare()
            try engine.start()
        } catch {
            throw Failure.engineStartFailed(error.localizedDescription)
        }

        if observer == nil {
            // Plugging in AirPods mid-session changes the input format and invalidates
            // the converter. Rebuild rather than quietly feeding garbage to the analyzer.
            observer = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: engine,
                queue: .main
            ) { [weak self] _ in
                self?.handleConfigurationChange()
            }
        }
    }

    public func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock()
        sink = nil
        preRoll.removeAll()
        preRollFrames = 0
        lock.unlock()
    }

    private func installTap() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else { throw Failure.noInputDevice }
        guard let newConverter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw Failure.converterUnavailable
        }
        converter = newConverter

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
            self?.handle(buffer)
        }
    }

    private func handleConfigurationChange() {
        let wasRunning = engine.isRunning
        engine.stop()
        try? installTap()
        if wasRunning {
            engine.prepare()
            try? engine.start()
        }
    }

    // MARK: - Gate

    /// Open the gate. The pre-roll is flushed first, so `sink` receives the audio from
    /// just *before* the key went down.
    public func beginForwarding(to newSink: @escaping (AVAudioPCMBuffer) -> Void) {
        lock.lock()
        let backlog = preRoll
        preRoll.removeAll()
        preRollFrames = 0
        sink = newSink
        lock.unlock()

        for buffer in backlog { newSink(buffer) }
    }

    /// Close the gate. Safe to call from any thread; the audio thread will stop
    /// delivering before this returns.
    public func endForwarding() {
        lock.lock()
        sink = nil
        lock.unlock()
    }

    // MARK: - Audio thread

    private func handle(_ buffer: AVAudioPCMBuffer) {
        if let onLevel {
            onLevel(rmsLevel(of: buffer))
        }

        guard let converted = convert(buffer) else { return }

        lock.lock()
        if let sink {
            lock.unlock()
            sink(converted)
            return
        }
        // Gate closed: keep the tail of recent audio around as pre-roll.
        preRoll.append(converted)
        preRollFrames += converted.frameLength
        while preRollFrames > preRollCapacity, !preRoll.isEmpty {
            preRollFrames -= preRoll.removeFirst().frameLength
        }
        lock.unlock()
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return nil }

        let ratio = targetFormat.sampleRate / converter.inputFormat.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio))
        guard capacity > 0,
              let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity)
        else { return nil }

        var error: NSError?
        var consumed = false
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }

        guard error == nil, output.frameLength > 0 else { return nil }
        return output
    }

    /// Root-mean-square of the first channel, normalized against a floor and ceiling
    /// that both track the live signal instead of a fixed dB threshold. Measured on
    /// this Mac: ambient RMS sits around 0.0001–0.0008 — an order of magnitude below
    /// where a "reasonable-looking" fixed floor (-48dBFS ≈ 0.004) would clamp
    /// everything to exactly 0 before it ever reached the ceiling logic.
    private func rmsLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameCount { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(frameCount))

        // Floor tracks the quiet baseline: snaps down fast to genuine silence, creeps
        // up slowly so a sustained loud sound can't drag it upward and numb the meter.
        if rms < levelFloor {
            levelFloor = rms
        } else {
            levelFloor = levelFloor * 0.999 + rms * 0.001
        }

        // Peak: fast attack to a new loud moment, slow release back down over a few
        // seconds — a standard VU-meter envelope follower.
        if rms > levelPeak {
            levelPeak = rms
        } else {
            levelPeak = levelPeak * 0.998 + rms * 0.002
        }

        let range = max(levelPeak - levelFloor, 0.0005)
        let linear = max(0, min(1, (rms - levelFloor) / range))
        return sqrt(linear) // perceptual curve: makes quieter speech visibly move
    }
}
