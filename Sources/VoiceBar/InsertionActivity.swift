import AppKit
import VoiceBarCore

/// Keep an opaque editor's paste tied to the user's original focus. Even a
/// switch away and back invalidates it. No typed characters are retained.
@MainActor
final class InsertionActivity {
    private(set) var changed = false
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    var isMonitoring: Bool { globalMonitor != nil && localMonitor != nil }

    init(shortcut: WakeShortcut) {
        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let receive: (NSEvent) -> Void = { [weak self] event in
            // Holding Control–Option–Space can emit repeated space keyDowns.
            if event.type == .keyDown, event.isARepeat, shortcut == .controlOptionSpace,
               event.keyCode == 49, event.modifierFlags.contains([.control, .option]) { return }
            self?.changed = true
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: receive)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            receive(event)
            return event
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed = true }
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        globalMonitor = nil
        localMonitor = nil
        activationObserver = nil
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }
}
