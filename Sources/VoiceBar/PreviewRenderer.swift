#if VOICEBAR_PREVIEW
import AppKit
import SwiftUI
import VoiceBarCore

/// Offscreen visual fixtures; never records, inserts text, or opens a window.
@MainActor
enum PreviewRenderer {
    static func export(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, phase) in [("idle", BarPhase.idle), ("listening", .listening), ("processing", .processing), ("complete", .complete)] {
            let state = AppState()
            state.phase = phase
            state.amplitude = 0.72
            let renderer = ImageRenderer(content: VoiceBarView(state: state)
                .frame(width: 360, height: 90)
                .background(Color(red: 0.95, green: 0.93, blue: 0.90)))
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: .png, properties: [:]) else {
                throw VoiceBarError("Could not render \(name).")
            }
            try data.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
}
#endif
