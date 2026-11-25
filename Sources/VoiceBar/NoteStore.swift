import AppKit
import Combine
import UniformTypeIdentifiers
import VoiceBarCore

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [VoiceNote] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRetrying = false
    @Published private(set) var error: String?
    @Published private(set) var unsavedNote: VoiceNote?
    @Published private(set) var destinationPath: String
    private let repository: NotesRepository?

    static var defaultDestination: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notes", isDirectory: true).appendingPathComponent("Quick Notes.md")
    }
    var destination: URL { URL(fileURLWithPath: destinationPath) }
    var usesDefaultDestination: Bool { destination.standardizedFileURL == Self.defaultDestination.standardizedFileURL }
    var pendingCount: Int { notes.filter { !$0.exported }.count }

    init(previewNotes: [VoiceNote]? = nil) {
        destinationPath = UserDefaults.standard.string(forKey: "notesDestinationPath") ?? Self.defaultDestination.path
        if let previewNotes {
            notes = previewNotes
            repository = nil
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(Bundle.main.bundleIdentifier ?? "app.lisan.mac", isDirectory: true)
            repository = NotesRepository(archiveURL: support.appendingPathComponent("notes.json"))
            isLoading = true
            Task {
                defer { isLoading = false }
                do { notes = try await repository!.load() }
                catch { self.error = "Couldn’t load your notes: \(error.localizedDescription)" }
            }
        }
    }

    func save(_ note: VoiceNote) async throws -> NoteSaveResult {
        guard let repository else { throw VoiceBarError("Notes cannot be saved from a design preview.") }
        do {
            let result = try await repository.save(note, to: destination)
            notes = try await repository.load()
            error = result.exportError.map { "Saved in Lisan. Couldn’t append to \(destination.lastPathComponent): \($0)" }
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            unsavedNote = note
            self.error = "Couldn’t save this note. Copy its text from Notes before quitting. \(error.localizedDescription)"
            throw error
        }
    }

    func retryExports() {
        guard !isRetrying, let repository else { return }
        isRetrying = true
        Task {
            defer { isRetrying = false }
            do {
                let results = try await repository.retryPendingExports()
                notes = try await repository.load()
                error = results.compactMap(\.exportError).first.map { "Couldn’t append a saved note: \($0)" }
            } catch { self.error = error.localizedDescription }
        }
    }

    func chooseExistingFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose a notes file"
        panel.message = "New notes will be appended. Existing content stays intact."
        panel.prompt = "Use file"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.directoryURL = destination.deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url { setDestination(url) }
    }

    func chooseNewFile() {
        let panel = NSSavePanel()
        panel.title = "Choose where notes go"
        panel.message = "Lisan appends notes to this Markdown file. Existing content is never replaced."
        panel.prompt = "Use file"
        panel.nameFieldStringValue = "Quick Notes.md"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.directoryURL = destination.deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url { setDestination(url) }
    }

    func restoreDefault() {
        destinationPath = Self.defaultDestination.path
        UserDefaults.standard.removeObject(forKey: "notesDestinationPath")
    }

    private func setDestination(_ url: URL) {
        guard ["md", "markdown"].contains(url.pathExtension.lowercased()) else {
            error = "Choose a Markdown file ending in .md or .markdown."
            return
        }
        destinationPath = url.path
        UserDefaults.standard.set(destinationPath, forKey: "notesDestinationPath")
    }
}
