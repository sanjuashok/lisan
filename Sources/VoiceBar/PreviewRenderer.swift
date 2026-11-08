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

        let brandPreview = VStack(alignment: .leading, spacing: 24) {
            SettingsHeader()
                .padding(20)
                .frame(width: 500, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            HStack(spacing: 16) {
                ForEach([false, true], id: \.self) { dark in
                    HStack(spacing: 12) {
                        Image(nsImage: BrandIcon.menuBarImage())
                            .foregroundStyle(dark ? Color.white : Color.black)
                        Text("lisan")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(dark ? Color.white : Color.black)
                    }
                    .padding(.horizontal, 16).frame(height: 32)
                    .background(dark ? Color(white: 0.15) : Color(white: 0.96),
                                in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(28)
        .background(Color(red: 0.91, green: 0.89, blue: 0.86))
        let renderer = ImageRenderer(content: brandPreview)
        renderer.scale = 3
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw VoiceBarError("Could not render the brand preview.")
        }
        try data.write(to: directory.appendingPathComponent("brand.png"))
    }
}
#endif
