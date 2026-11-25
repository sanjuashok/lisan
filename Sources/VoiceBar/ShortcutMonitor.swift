import AppKit
import VoiceBarCore

/// Prefer a passive session listener; preserve paired AppKit monitors as a
/// fallback when macOS cannot create it. Only one path feeds the recognizer.
@MainActor
final class ShortcutMonitor {
    enum Scope { case local, global, system }

    var shortcut: WakeShortcut = .function
    var onHold: ((Bool, Scope) -> Void)?
    var onCancel: (() -> Void)?
    var onModifierEvent: ((Int64, Bool, Scope) -> Void)?
    private var recognizer = ShortcutRecognizer()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var sessionTap: CFMachPort?
    private var sessionSource: CFRunLoopSource?
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
            removeSessionTap()
            removeGlobalMonitor()
            return false
        }
        if reinstall { removeSessionTap(); removeGlobalMonitor(); reset() }
        if sessionTap == nil { installSessionTap() }
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
                MainActor.assumeIsolated { self?.enqueue(event, scope: .global) }
            }
        }
        // Registration is not evidence of delivery. Settings reports separately
        // whether an actual shortcut arrived from another application.
        return sessionTap != nil || globalMonitor != nil
    }

    func stop() {
        removeSessionTap()
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

    private func installSessionTap() {
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, context in
                if let context {
                    let monitor = Unmanaged<ShortcutMonitor>.fromOpaque(context).takeUnretainedValue()
                    MainActor.assumeIsolated { monitor.receiveSessionEvent(type, event: event) }
                }
                // Passive observation: never consume or rewrite a key event.
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()),
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return }
        reset()
        sessionTap = tap
        sessionSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeSessionTap() {
        if let sessionTap { CFMachPortInvalidate(sessionTap) }
        if let sessionSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), sessionSource, .commonModes) }
        sessionTap = nil
        sessionSource = nil
    }

    private func receiveSessionEvent(_ type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let sessionTap { CGEvent.tapEnable(tap: sessionTap, enable: true) }
            // Audio shutdown must not delay the event-tap callback either.
            DispatchQueue.main.async { [weak self] in self?.reset() }
            return
        }
        let input: WakeKeyEvent
        switch type {
        case .flagsChanged: input = .flagsChanged
        case .keyDown: input = .keyDown
        case .keyUp: input = .keyUp
        default: return
        }
        enqueue(input, key: event.getIntegerValueField(.keyboardEventKeycode),
                function: event.flags.contains(.maskSecondaryFn), control: event.flags.contains(.maskControl),
                option: event.flags.contains(.maskAlternate), scope: .system)
    }

    private func enqueue(_ event: NSEvent, scope: Scope) {
        // A session tap also sees this app's events. Ignore the fallback copies
        // to prevent asynchronous duplicate delivery from starting two captures.
        guard sessionTap == nil else { return }
        let input: WakeKeyEvent
        switch event.type {
        case .flagsChanged: input = .flagsChanged
        case .keyDown: input = .keyDown
        case .keyUp: input = .keyUp
        default: return
        }
        let flags = event.modifierFlags
        enqueue(input, key: Int64(event.keyCode), function: flags.contains(.function),
                control: flags.contains(.control), option: flags.contains(.option), scope: scope)
    }

    private func enqueue(_ input: WakeKeyEvent, key: Int64, function: Bool, control: Bool, option: Bool, scope: Scope) {
        let queuedGeneration = generation
        // AX queries and audio-engine startup must not block keyboard dispatch.
        // FIFO delivery preserves a quick press/release; reset invalidates any
        // queued events so a stopped/cancelled listener cannot start recording.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == queuedGeneration else { return }
            if input == .flagsChanged {
                self.onModifierEvent?(key, function, scope)
            }
            if input == .keyDown && key == 53 { self.reset(); return }
            if let transition = self.recognizer.receive(input, keyCode: key,
                function: function, control: control, option: option, shortcut: self.shortcut) {
                self.onHold?(transition, scope)
            }
        }
    }
}
