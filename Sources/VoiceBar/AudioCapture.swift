import AVFoundation
import Foundation

struct RecordedAudio: Sendable {
    let samples: [Float]
    let sampleRate: Double
    let peak: Float
    var duration: Double { Double(samples.count) / sampleRate }
}

/// Tap storage is bounded, synchronized, and never persists microphone audio.
private final class AudioStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []
    private var peak: Float = 0
    private var meterFrames = 0
    private let capacity: Int
    init(sampleRate: Double) {
        capacity = Int(sampleRate * 120)
        samples.reserveCapacity(capacity)
    }
    func append(_ buffer: AVAudioPCMBuffer) -> Double? {
        guard let channels = buffer.floatChannelData else { return nil }
        lock.lock(); defer { lock.unlock() }
        let count = min(Int(buffer.frameLength), capacity - samples.count)
        guard count > 0 else { return nil }
        var sum: Float = 0
        for frame in 0..<count {
            var value: Float = 0
            for channel in 0..<Int(buffer.format.channelCount) { value += channels[channel][frame] }
            value /= Float(buffer.format.channelCount)
            samples.append(value)
            peak = max(peak, abs(value))
            sum += value * value
        }
        meterFrames += count
        // At most 30 UI updates per second; no timer runs while idle.
        guard meterFrames >= Int(buffer.format.sampleRate / 30) else { return nil }
        meterFrames = 0
        let rms = sqrt(Double(sum) / Double(count))
        return min(1, max(0, (20 * log10(max(rms, 0.00001)) + 55) / 45))
    }
    func snapshot(sampleRate: Double) -> RecordedAudio {
        lock.lock(); defer { lock.unlock() }
        return RecordedAudio(samples: samples, sampleRate: sampleRate, peak: peak)
    }
}

@MainActor
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var storage: AudioStorage?
    private var rate: Double = 0
    private var tapped = false
    var onAmplitude: ((Double) -> Void)?

    func start() throws {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw VoiceBarError("Allow microphone access in Settings before dictating.")
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0,
              format.commonFormat == .pcmFormatFloat32, !format.isInterleaved else {
            throw VoiceBarError("No usable microphone found. Check your sound input device.")
        }
        rate = format.sampleRate
        let storage = AudioStorage(sampleRate: rate)
        self.storage = storage
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            if let level = storage.append(buffer) {
                Task { @MainActor [weak self] in self?.onAmplitude?(level) }
            }
        }
        tapped = true
        engine.prepare()
        do { try engine.start() } catch { cancel(); throw error }
    }
    func stop() -> RecordedAudio? {
        engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        let audio = storage?.snapshot(sampleRate: rate)
        storage = nil
        return audio
    }
    func cancel() { _ = stop() }
}
