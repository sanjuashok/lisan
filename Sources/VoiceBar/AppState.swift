import AppKit
import Combine
import VoiceBarCore

@MainActor
final class AppState: ObservableObject {
    let notes: NoteStore
    @Published var selectedTab: AppTab = .notes
    @Published var savingAsNote = false
    @Published var canChooseNote = false

    init(notes: NoteStore? = nil) { self.notes = notes ?? NoteStore() }

    @Published var phase: BarPhase = .idle
    @Published var amplitude: Double = 0
    @Published var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: "enabled") }
    }
    @Published var shortcut = WakeShortcut(rawValue: UserDefaults.standard.string(forKey: "shortcut") ?? "") ?? .function {
        didSet { UserDefaults.standard.set(shortcut.rawValue, forKey: "shortcut") }
    }
    @Published var smartCleanup = UserDefaults.standard.object(forKey: "smartCleanup") as? Bool ?? true {
        didSet { UserDefaults.standard.set(smartCleanup, forKey: "smartCleanup") }
    }
    @Published var cleanupInstructions = UserDefaults.standard.string(forKey: "cleanupInstructions") ?? "" {
        didSet { UserDefaults.standard.set(cleanupInstructions, forKey: "cleanupInstructions") }
    }
    @Published var modelsReady = false
    @Published var preparing = false
    @Published var modelProgress: Double = 0
    @Published var status = "Set up local dictation in Settings."
    @Published var lastTranscript = ""
    @Published var microphoneGranted = false
    @Published var accessibilityGranted = false
    @Published var inputMonitoringGranted = false
    @Published var permissionFeedback = ""
    @Published var restarting = false
    @Published var shortcutAvailable = false
    @Published var lastShortcutEvent = "No shortcut press detected yet."
    @Published var recentModifierEvents: [String] = []
    @Published var shortcutTestActive = false
    @Published var lastLatency: Double?
    @Published var completionLabel = "Inserted"
    @Published var failureLabel = ""

}

enum AppTab: String, CaseIterable, Identifiable {
    case notes = "Notes", settings = "Settings"
    var id: Self { self }
    var icon: String { self == .notes ? "note.text" : "slider.horizontal.3" }
}

struct VoiceBarError: LocalizedError {
    let message: String
    let barLabel: String?
    init(_ message: String, barLabel: String? = nil) {
        self.message = message
        self.barLabel = barLabel
    }
    var errorDescription: String? { message }
}
