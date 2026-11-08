import AVFoundation
import Foundation
import VoiceBarCore
#if !VOICEBAR_PREVIEW
import FluidAudio
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

actor SpeechService {
    #if !VOICEBAR_PREVIEW
    private var manager: AsrManager?
    #endif

    func prepare(allowDownload: Bool, progress: @escaping @Sendable (Double) -> Void) async throws {
        #if VOICEBAR_PREVIEW
        throw VoiceBarError("UI preview build. Build with Xcode 26 or later to enable local transcription.")
        #else
        if manager != nil { return }
        ModelHub.offlineMode = !allowDownload
        defer { ModelHub.offlineMode = true }
        let directory = AsrModels.defaultCacheDirectory(for: .v3)
        let models: AsrModels
        if allowDownload {
            models = try await AsrModels.downloadAndLoad(version: .v3, progressHandler: { progress($0.fractionCompleted) })
        } else {
            // This API reads only local assets; startup never initiates a model download.
            models = try AsrModels.loadLocal(from: directory, version: .v3)
        }
        try Task.checkCancellation()
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        self.manager = manager
        progress(1)
        #endif
    }

    func transcribe(_ audio: RecordedAudio) async throws -> String {
        #if VOICEBAR_PREVIEW
        throw VoiceBarError("Transcription is unavailable in the UI preview build.")
        #else
        guard let manager else { throw VoiceBarError("Download the speech model in Settings first.") }
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: audio.sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.samples.count)),
              let pointer = buffer.floatChannelData?[0] else { throw VoiceBarError("Could not prepare microphone audio.") }
        buffer.frameLength = buffer.frameCapacity
        audio.samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress { pointer.update(from: base, count: source.count) }
        }
        let samples = try AudioConverter().resampleBuffer(buffer)
        var decoderState = try TdtDecoderState()
        let result = try await manager.transcribe(samples, decoderState: &decoderState)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        #endif
    }

    func clean(_ transcript: String, intelligent: Bool, instructions: String) async -> String {
        let fallback = BasicCleanup.clean(transcript)
        guard intelligent, !fallback.isEmpty else { return fallback }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), SystemLanguageModel.default.availability == .available {
            do {
                // A fresh session prevents previous dictation from affecting this text.
                let session = LanguageModelSession(instructions: CleanupPrompt.instructions(custom: instructions))
                let response = try await session.respond(to: "Edit this dictated text:\n<dictation>\n\(transcript)\n</dictation>",
                                                         options: GenerationOptions(sampling: nil, temperature: 0))
                let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                // Reject empty or wildly expanded output; keep the usable local transcript.
                if !cleaned.isEmpty && cleaned.count <= max(80, transcript.count * 2) { return cleaned }
            } catch { /* Unavailable / refused / context exceeded: use conservative local cleanup. */ }
        }
        #endif
        return fallback
    }

    nonisolated static var cleanupDescription: String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return "Apple Intelligence is ready. Cleanup runs entirely on this Mac."
            case .unavailable: return "Apple Intelligence is unavailable. Basic punctuation and filler cleanup will be used."
            }
        }
        #endif
        return "Basic cleanup is available. Intelligent grammar cleanup requires macOS 26 and Apple Intelligence."
    }
}
