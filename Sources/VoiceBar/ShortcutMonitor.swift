import AppKit
import VoiceBarCore

/// Observe both scopes: AppKit's global monitor excludes this application,
/// and its local monitor excludes every other application.
@MainActor
final class ShortcutMonitor {
    enum Scope { case local, global }

    var shortcut: WakeShortcut = .function
    var onHold: ((Bool, Scope) -> Void)?
    var onCancel: (() -> Void)?
    private var recognizer = ShortcutRecognizer()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var generation: UInt64 = 0
    private let eventMask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]

    func start(reinstall: Bool = false) -> Bool {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
                MainActor.assumeIsolated { self?.enqueue(event, scope: .local) }
                return event
            }
        }
        guard AXIsProcessTrusted() || CGPreflightListenEventAccess() else {
            removeGlobalMonitor()
            return false
        }
        if reinstall { removeGlobalMonitor(); reset() }
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
                MainActor.assumeIsolated { self?.enqueue(event, scope: .global) }
            }
        }
        // Registration is not evidence of delivery. Settings reports separately
        // whether an actual shortcut arrived from another application.
        return globalMonitor != nil
    }

    func stop() {
        removeGlobalMonitor()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        localMonitor = nil
        reset()
    }

    func reset() {
        generation &+= 1
        recognizer.reset()
        onCancel?()
    }

    private func removeGlobalMonitor() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        globalMonitor = nil
    }

    private func enqueue(_ event: NSEvent, scope: Scope) {
        let input: WakeKeyEvent
        switch event.type {
        case .flagsChanged: input = .flagsChanged
        case .keyDown: input = .keyDown
        case .keyUp: input = .keyUp
        default: return
        }
        let key = Int64(event.keyCode)
        let flags = event.modifierFlags
        let queuedGeneration = generation
        // AX queries and audio-engine startup must not block keyboard dispatch.
        // FIFO delivery preserves a quick press/release; reset invalidates any
        // queued events so a stopped/cancelled listener cannot start recording.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == queuedGeneration else { return }
            if input == .keyDown && key == 53 { self.reset(); return }
            if let transition = self.recognizer.receive(input, keyCode: key,
                function: flags.contains(.function), control: flags.contains(.control),
                option: flags.contains(.option), shortcut: self.shortcut) {
                self.onHold?(transition, scope)
            }
        }
    }
}
