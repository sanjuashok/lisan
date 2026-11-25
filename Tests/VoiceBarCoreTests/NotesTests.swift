import Foundation
import VoiceBarCore

enum NotesTests {
    static func run() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lisan-notes-tests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archive = directory.appendingPathComponent("support/notes.json")
        let destination = directory.appendingPathComponent("Documents/Notes/Quick Notes.md")
        let repository = NotesRepository(archiveURL: archive)
        let winter = ISO8601DateFormatter().date(from: "2026-11-24T16:42:00Z")!
        let eastern = TimeZone(identifier: "America/New_York")!
        let first = VoiceNote(text: "Remember the idea.\nதமிழ் 👋", capturedAt: winter, timeZone: eastern)
        precondition(first.timestamp == "NOV 24, 2026 · 11:42 AM · EST", first.timestamp)
        let summer = VoiceNote(text: "Summer", capturedAt: ISO8601DateFormatter().date(from: "2026-07-24T16:42:00Z")!, timeZone: eastern)
        precondition(summer.timestamp == "JUL 24, 2026 · 12:42 PM · EDT")
        let decoded = try JSONDecoder().decode(VoiceNote.self, from: JSONEncoder().encode(first))
        precondition(decoded == first && decoded.timeZoneIdentifier == eastern.identifier)
        print("PASS: capture timestamps, DST, and Unicode persistence")

        let saved = try await repository.save(first, to: destination)
        precondition(saved.note.exported && saved.exportError == nil)
        let reopened = NotesRepository(archiveURL: archive)
        let loaded = try await reopened.load()
        precondition(loaded.count == 1 && loaded[0].text == first.text && loaded[0].timestamp == first.timestamp)
        let original = try String(contentsOf: destination, encoding: .utf8)
        precondition(original.contains(first.markdown))
        let second = VoiceNote(text: "Second note", capturedAt: winter.addingTimeInterval(30), timeZone: eastern)
        _ = try await repository.save(second, to: destination)
        let appended = try String(contentsOf: destination, encoding: .utf8)
        precondition(appended.hasPrefix(original) && appended.contains(second.markdown))
        _ = try await repository.save(first, to: destination)
        let deduplicated = try String(contentsOf: destination, encoding: .utf8)
        precondition(deduplicated == appended)
        print("PASS: default directory creation, append-only writes, restart, and duplicate prevention")

        let custom = directory.appendingPathComponent("custom.md")
        let preexisting = "# My existing notes\n\nKeep this content.\n"
        try preexisting.write(to: custom, atomically: true, encoding: .utf8)
        let third = VoiceNote(text: "Custom destination")
        _ = try await repository.save(third, to: custom)
        let customContents = try String(contentsOf: custom, encoding: .utf8)
        precondition(customContents.hasPrefix(preexisting) && customContents.contains(third.text))
        let defaultContents = try String(contentsOf: destination, encoding: .utf8)
        precondition(defaultContents == appended)
        let all = try await reopened.load()
        precondition(all.count == 3)
        print("PASS: custom file routing preserves existing content and all local cards")

        let blocked = directory.appendingPathComponent("unavailable.md")
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
        let pending = VoiceNote(text: "Keep me even when the export fails")
        let failedExport = try await repository.save(pending, to: blocked)
        precondition(!failedExport.note.exported && failedExport.exportError != nil)
        let afterFailure = try await reopened.load()
        precondition(afterFailure.contains { $0.id == pending.id && !$0.exported })
        try FileManager.default.removeItem(at: blocked)
        let retries = try await repository.retryPendingExports()
        precondition(retries.count == 1 && retries[0].note.exported)
        let retryContents = try String(contentsOf: blocked, encoding: .utf8)
        precondition(retryContents.contains(pending.text))

        // Simulate a crash after Markdown append but before the exported flag was
        // written. A retry must recognize the entry and leave the file untouched.
        var simulatedCrash = try await reopened.load()
        simulatedCrash[simulatedCrash.firstIndex { $0.id == pending.id }!].exported = false
        try JSONEncoder().encode(simulatedCrash).write(to: archive, options: .atomic)
        _ = try await repository.retryPendingExports()
        let recoveredContents = try String(contentsOf: blocked, encoding: .utf8)
        precondition(recoveredContents == retryContents)
        print("PASS: failed file writes keep local notes; retries and crash recovery do not duplicate")

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<8 {
                group.addTask { _ = try await repository.save(VoiceNote(text: "Concurrent \(index)"), to: custom) }
            }
            try await group.waitForAll()
        }
        let concurrent = try await reopened.load()
        precondition(concurrent.count == 12)
        let corrupt = Data("invalid archive".utf8)
        try corrupt.write(to: archive)
        do {
            _ = try await repository.save(VoiceNote(text: "Do not overwrite"), to: custom)
            preconditionFailure("A corrupt archive must not be silently overwritten")
        } catch { /* Expected. */ }
        let archiveAfterError = try Data(contentsOf: archive)
        precondition(archiveAfterError == corrupt)
        print("PASS: serialized saves and corrupt-archive protection")

        let cancelledArchive = directory.appendingPathComponent("cancelled/notes.json")
        let cancelledRepository = NotesRepository(archiveURL: cancelledArchive)
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try await cancelledRepository.save(VoiceNote(text: "Cancelled"), to: destination)
        }
        do {
            try await cancelled.value
            preconditionFailure("A cancelled capture must not create a note")
        } catch is CancellationError { /* Expected. */ }
        precondition(!FileManager.default.fileExists(atPath: cancelledArchive.path))
        do {
            _ = try await cancelledRepository.save(VoiceNote(text: " \n\t "), to: destination)
            preconditionFailure("Empty transcripts must not create notes")
        } catch NoteArchiveError.emptyText { /* Expected. */ }
        precondition(!FileManager.default.fileExists(atPath: cancelledArchive.path))
        print("PASS: cancelled captures and empty transcripts leave no notes or files")

        precondition(!TextInputFocus.isEditable(role: nil, hasSelection: false, editable: nil, canSetValue: false))
        precondition(!TextInputFocus.isEditable(role: "AXWindow", hasSelection: false, editable: nil, canSetValue: false))
        precondition(!TextInputFocus.isEditable(role: "AXButton", hasSelection: false, editable: nil, canSetValue: true))
        precondition(!TextInputFocus.isEditable(role: "AXStaticText", hasSelection: true, editable: nil, canSetValue: false))
        precondition(!TextInputFocus.isEditable(role: "AXTextArea", hasSelection: true, editable: false, canSetValue: false))
        precondition(TextInputFocus.isEditable(role: "AXTextArea", hasSelection: false, editable: nil, canSetValue: false))
        precondition(TextInputFocus.isEditable(role: "AXTextField", hasSelection: false, editable: nil, canSetValue: false))
        precondition(TextInputFocus.isEditable(role: "AXGroup", hasSelection: false, editable: true, canSetValue: false))
        precondition(TextInputFocus.isEditable(role: "AXGroup", hasSelection: true, editable: nil, canSetValue: false))
        print("PASS: no-field note routing and partially exposed editor recognition")
        print("7 notes regression groups passed.")
    }
}
