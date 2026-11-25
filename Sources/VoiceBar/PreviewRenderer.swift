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
            let state = AppState(notes: NoteStore(previewNotes: []))
            state.phase = phase
            state.canChooseNote = phase == .listening
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

        let fixtureDate = ISO8601DateFormatter().date(from: "2026-11-24T16:42:00Z")!
        let fixtures = [
            VoiceNote(text: "The best ideas tend to arrive when I’m doing something else. Make it effortless to catch them, then get back to the moment.", capturedAt: fixtureDate, timeZone: TimeZone(identifier: "America/New_York")!, exported: true),
            VoiceNote(text: "A small thought for the next version: the interface should feel like a quiet place to land. Warm light, a little space, and only what you need.", capturedAt: fixtureDate.addingTimeInterval(-3600), timeZone: TimeZone(identifier: "America/New_York")!, exported: true),
            VoiceNote(text: "Take the long way home today.", capturedAt: fixtureDate.addingTimeInterval(-86400), timeZone: TimeZone(identifier: "America/New_York")!, exported: true)
        ]
        for dark in [false, true] {
            for empty in [false, true] {
                let preview = HStack(spacing: 0) {
                    LisanSidebar(selection: .constant(.notes))
                    Divider()
                    NotesView(store: NoteStore(previewNotes: empty ? [] : fixtures), shortcut: .function)
                }
                .frame(width: 860, height: 700)
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, dark ? .dark : .light)
                try render(preview, name: "notes\(empty ? "-empty" : "")\(dark ? "-dark" : "")", to: directory)
            }
        }
        let noteState = AppState(notes: NoteStore(previewNotes: []))
        noteState.phase = .processing
        noteState.savingAsNote = true
        try render(VoiceBarView(state: noteState).frame(width: 360, height: 90)
            .background(Color(red: 0.95, green: 0.93, blue: 0.90)), name: "saving-note", to: directory)

        let settingsPreview = VStack(alignment: .leading, spacing: 18) {
            Text("Settings").font(.system(size: 32, weight: .semibold))
            Text("YOUR NOTES").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary)
            NoteDestinationSettings(store: NoteStore(previewNotes: []))
                .padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        }.padding(32).frame(width: 600).background(Color(nsColor: .windowBackgroundColor))
        try render(settingsPreview, name: "notes-settings", to: directory)

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

    private static func render<Content: View>(_ content: Content, name: String, to directory: URL) throws {
        // ImageRenderer omits native scroll views and menu controls. Render the
        // actual AppKit host so the fixtures include cards and file controls.
        let host = NSHostingView(rootView: content)
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -10000, y: -10000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil); window.close() }
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw VoiceBarError("Could not render \(name).")
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw VoiceBarError("Could not render \(name).")
        }
        try data.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
#endif
