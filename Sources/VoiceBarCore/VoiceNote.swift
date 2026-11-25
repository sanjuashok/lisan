import Foundation

public enum NoteArchiveError: LocalizedError {
    case emptyText
    public var errorDescription: String? { "There is no text to save." }
}

public struct VoiceNote: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let capturedAt: Date
    public let timeZoneIdentifier: String
    public let timestamp: String
    public var destinationPath: String
    public var exported: Bool

    public init(id: UUID = UUID(), text: String, capturedAt: Date = Date(), timeZone: TimeZone = .current,
                destinationPath: String = "", exported: Bool = false) {
        self.id = id
        self.text = text
        self.capturedAt = capturedAt
        self.timeZoneIdentifier = timeZone.identifier
        self.destinationPath = destinationPath
        self.exported = exported
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d, yyyy '·' h:mm a '·' z"
        self.timestamp = formatter.string(from: capturedAt).uppercased()
    }

    /// Hidden in rendered Markdown; allows recovery after a crash between the
    /// append and archive update without appending the same note twice.
    public var exportMarker: String { "<!-- lisan-note: \(id.uuidString) -->" }
    public var markdown: String { "## \(timestamp)\n\n\(text)\n\n\(exportMarker)\n" }
}

public struct NoteSaveResult: Sendable {
    public let note: VoiceNote
    public let exportError: String?
}

/// Serializes local persistence and file appends, off the UI thread. The local
/// archive is committed first so a denied or unavailable export never loses text.
public actor NotesRepository {
    private let archiveURL: URL
    public init(archiveURL: URL) { self.archiveURL = archiveURL }

    public func load() throws -> [VoiceNote] {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else { return [] }
        return try JSONDecoder().decode([VoiceNote].self, from: Data(contentsOf: archiveURL))
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    public func save(_ note: VoiceNote, to destination: URL) throws -> NoteSaveResult {
        try Task.checkCancellation()
        guard !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NoteArchiveError.emptyText
        }
        var notes = try load()
        if let existing = notes.first(where: { $0.id == note.id }) {
            return try export(existing, in: &notes)
        }
        var pending = note
        pending.destinationPath = destination.path
        pending.exported = false
        notes.insert(pending, at: 0)
        try Task.checkCancellation()
        try persist(notes)
        return try export(pending, in: &notes)
    }

    public func retryPendingExports() throws -> [NoteSaveResult] {
        var notes = try load()
        let pending = notes.filter { !$0.exported }.reversed()
        return try pending.map { try export($0, in: &notes) }
    }

    private func export(_ note: VoiceNote, in notes: inout [VoiceNote]) throws -> NoteSaveResult {
        guard !note.exported else { return NoteSaveResult(note: note, exportError: nil) }
        do {
            try append(note, to: URL(fileURLWithPath: note.destinationPath))
            var saved = note
            saved.exported = true
            if let index = notes.firstIndex(where: { $0.id == note.id }) { notes[index] = saved }
            try persist(notes)
            return NoteSaveResult(note: saved, exportError: nil)
        } catch {
            return NoteSaveResult(note: note, exportError: error.localizedDescription)
        }
    }

    private func persist(_ notes: [VoiceNote]) throws {
        try FileManager.default.createDirectory(at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(notes).write(to: archiveURL, options: .atomic)
    }

    private func append(_ note: VoiceNote, to url: URL) throws {
        guard ["md", "markdown"].contains(url.pathExtension.lowercased()), url.standardizedFileURL != archiveURL.standardizedFileURL else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !manager.fileExists(atPath: url.path) {
            // Never truncate an existing destination, including a file created
            // between the existence check and this write.
            try Data().write(to: url, options: .withoutOverwriting)
        }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        let existing = try handle.readToEnd() ?? Data()
        if existing.range(of: Data(note.exportMarker.utf8)) != nil { return }
        let separator = existing.isEmpty ? "" : "\n\n"
        let originalLength = try handle.seekToEnd()
        do {
            try handle.write(contentsOf: Data((separator + note.markdown).utf8))
            try handle.synchronize()
        } catch {
            // Roll back a partial append when possible so retrying doesn't leave
            // a truncated copy of the same note before its complete entry.
            try? handle.truncate(atOffset: originalLength)
            throw error
        }
    }
}

/// A missing AX tree is not evidence of a text field. Accept partial editor
/// data when it still identifies an editor, without requiring a readable value.
public enum TextInputFocus {
    public static func isEditable(role: String?, hasSelection: Bool, editable: Bool?, canSetValue: Bool) -> Bool {
        if editable == false { return false }
        if ["AXButton", "AXCheckBox", "AXRadioButton", "AXLink", "AXMenuItem", "AXStaticText"].contains(role ?? "") { return false }
        return editable == true || canSetValue || hasSelection ||
            ["AXTextField", "AXTextArea", "AXComboBox"].contains(role ?? "")
    }
}
