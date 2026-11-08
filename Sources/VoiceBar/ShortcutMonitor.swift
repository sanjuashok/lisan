import AppKit
import VoiceBarCore

/// A non-consuming event tap observes physical press/release across applications.
/// Fn remains available to macOS; Settings explains how to turn off its system action.
@MainActor
final class ShortcutMonitor {
    var shortcut: WakeShortcut = .function
    var onHold: ((Bool) -> Void)?
    var onCancel: (() -> Void)?
    private var recognizer = ShortcutRecognizer()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var localMonitor: Any?

    func start() -> Bool {
        // Local events work in Settings even before macOS grants global monitoring.
        // Both paths share the hold tracker, so a key is never handled twice.
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
                if let cgEvent = event.cgEvent {
                    MainActor.assumeIsolated { self?.receive(cgEvent.type, event: cgEvent) }
                }
                return event
            }
        }
        guard CGPreflightListenEventAccess() || AXIsProcessTrusted() else {
            if let tap { CFMachPortInvalidate(tap) }
            if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
            tap = nil; source = nil
            return false
        }
        if let tap, CGEvent.tapIsEnabled(tap: tap) { return true }
        if let oldTap = tap { CFMachPortInvalidate(oldTap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                               options: .listenOnly, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<ShortcutMonitor>.fromOpaque(context).takeUnretainedValue()
            // The tap is installed on the main run loop.
            MainActor.assumeIsolated { monitor.receive(type, event: event) }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return false }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        localMonitor = nil
        reset()
    }
    func reset() {
        recognizer.reset()
        onCancel?()
    }
    private func receive(_ type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            reset()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyDown && key == 53 { reset(); return }
        let input: WakeKeyEvent
        switch type {
        case .flagsChanged: input = .flagsChanged
        case .keyDown: input = .keyDown
        case .keyUp: input = .keyUp
        default: return
        }
        if let transition = recognizer.receive(input, keyCode: key,
            function: event.flags.contains(.maskSecondaryFn), control: event.flags.contains(.maskControl),
            option: event.flags.contains(.maskAlternate), shortcut: shortcut) { onHold?(transition) }
    }
}
