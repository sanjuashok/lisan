import AppKit
import ApplicationServices
import Carbon
import VoiceBarCore

@MainActor
final class TextInsertion {
    struct Target {
        let pid: pid_t
        let element: AXUIElement?
        let window: AXUIElement?
        let snapshot: InsertionSnapshot
        let requiresSameElement: Bool
        let activity: InsertionActivity
        let screen: NSScreen?
    }
    enum Result { case inserted, pasteSent }

    func capture(shortcut: WakeShortcut) throws -> Target? {
        guard AXIsProcessTrusted() else {
            throw VoiceBarError("lisan needs Accessibility access to insert text. Click Open Settings beside Accessibility below. On newer macOS versions, this permission is called Device Control and Data Access.",
                                barLabel: "Allow Accessibility access in Settings")
        }
        try rejectSecureInput(nil)
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let activity = InsertionActivity(shortcut: shortcut)
        var focused = focusedElement(pid: pid)
        if focused.flatMap({ selectionSnapshot($0) }) == nil {
            // Electron and Chromium enable their trees on demand. Do not assume
            // the tree is populated synchronously after either request succeeds.
            let application = AXUIElementCreateApplication(pid)
            _ = AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            _ = AXUIElementSetAttributeValue(application, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            focused = focusedElement(pid: pid)
        }
        try rejectSecureInput(focused)
        let snapshot = snapshot(focused)
        let role = focused.flatMap { stringAttribute($0, kAXRoleAttribute) }
        // These roles identify an actual editor; containers can become a text
        // element later when a browser finishes enabling its accessibility tree.
        let requiresSameElement = snapshot.selection != nil || role == kAXTextFieldRole || role == kAXTextAreaRole || role == kAXComboBoxRole
        guard isEditable(focused) else { return nil }
        guard activity.isMonitoring else {
            throw VoiceBarError("Could not monitor focus changes. Check Accessibility access and restart lisan.")
        }
        let target = Target(pid: pid, element: focused, window: focusedWindow(pid: pid), snapshot: snapshot,
                            requiresSameElement: requiresSameElement, activity: activity,
                            screen: focused.flatMap { screenForElement($0) } ?? NSScreen.main)
        try validate(target)
        return target
    }

    func insert(_ text: String, into target: Target) async throws -> Result {
        try validate(target)
        try Task.checkCancellation()
        // Use the editor's normal paste action. Some web editors acknowledge an
        // AXSelectedText write without updating their actual document/input state.
        let expected = target.snapshot.selection?.valueAfterInserting(text)
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        } ?? []
        pasteboard.clearContents()
        let copied = pasteboard.setString(text, forType: .string)
        let changeCount = pasteboard.changeCount
        defer {
            // Do not erase something the user copied while the paste was in flight.
            if pasteboard.changeCount == changeCount {
                pasteboard.clearContents()
                let items = saved.map { values -> NSPasteboardItem in
                    let item = NSPasteboardItem()
                    for (type, data) in values { item.setData(data, forType: type) }
                    return item
                }
                if !items.isEmpty { pasteboard.writeObjects(items) }
            }
        }
        guard copied else { throw VoiceBarError("Could not prepare the clipboard. Try dictating again.") }
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            throw VoiceBarError("Could not send paste. Check Accessibility access and try dictating again.")
        }
        down.flags = .maskCommand; up.flags = .maskCommand
        try validate(target)
        try Task.checkCancellation()
        target.activity.stop()
        down.post(tap: .cgSessionEventTap); up.post(tap: .cgSessionEventTap)
        // Keep the clipboard available while the editor consumes it. Once paste
        // is dispatched, cancellation must not restore the clipboard prematurely.
        // Never retry a dispatched paste: a delayed editor could insert it twice.
        for attempt in 0..<10 {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { continuation.resume() }
            }
            if attempt >= 4, let expected, let element = target.element,
               stringAttribute(element, kAXValueAttribute) == expected {
                return .inserted
            }
        }
        if let element = target.element, let original = target.snapshot.selection,
           let current = selectionSnapshot(element), current.matches(original), expected != nil {
            throw VoiceBarError("The app did not accept the paste. Try another text field and dictate again.")
        }
        // Some editors do not expose their value, or normalize it on paste.
        // Do not claim verified insertion when we cannot read the result.
        return .pasteSent
    }

    private func validate(_ target: Target) throws {
        let current = focusedElement(pid: target.pid)
        try rejectSecureInput(current)
        let sameElement = target.element.map { original in current.map { CFEqual($0, original) } ?? false } ?? false
        let sameWindow = target.window.map { original in focusedWindow(pid: target.pid).map { CFEqual($0, original) } ?? false } ?? true
        guard !target.activity.changed,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid,
              !isNonEditor(current),
              sameWindow, !target.requiresSameElement || sameElement,
              target.snapshot.matches(snapshot(current)) else {
            throw VoiceBarError("The cursor or text changed. Keep the original text field focused and try dictating again.")
        }
    }

    private func isNonEditor(_ element: AXUIElement?) -> Bool {
        guard let element, let role = stringAttribute(element, kAXRoleAttribute) else { return false }
        return [kAXButtonRole, kAXCheckBoxRole, kAXRadioButtonRole, "AXLink", kAXMenuItemRole].contains(role)
    }

    private func isEditable(_ element: AXUIElement?) -> Bool {
        guard let element else { return false }
        var editableValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, "AXEditable" as CFString, &editableValue)
        var canSetValue: DarwinBoolean = false
        _ = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &canSetValue)
        return TextInputFocus.isEditable(role: stringAttribute(element, kAXRoleAttribute),
                                         hasSelection: selectionSnapshot(element) != nil,
                                         editable: editableValue as? Bool,
                                         canSetValue: canSetValue.boolValue && stringAttribute(element, kAXValueAttribute) != nil)
    }

    private func rejectSecureInput(_ element: AXUIElement?) throws {
        var current = element
        var secure = IsSecureEventInputEnabled()
        for _ in 0..<12 {
            guard let node = current else { break }
            if stringAttribute(node, kAXSubroleAttribute) == kAXSecureTextFieldSubrole {
                secure = true
                break
            }
            current = elementAttribute(node, kAXParentAttribute)
        }
        if secure { throw VoiceBarError("lisan does not dictate into password fields or while secure keyboard input is enabled.") }
    }

    private func focusedWindow(pid: pid_t) -> AXUIElement? {
        elementAttribute(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute)
    }
    private func focusedElement(pid: pid_t) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        if let focused = focusedElement(in: system) {
            var focusedPID: pid_t = 0
            if AXUIElementGetPid(focused, &focusedPID) == .success, focusedPID == pid {
                return deepestFocusedElement(focused)
            }
        }
        let application = AXUIElementCreateApplication(pid)
        if let focused = focusedElement(in: application) { return deepestFocusedElement(focused) }
        if let window = focusedWindow(pid: pid), let focused = focusedElement(in: window) {
            return deepestFocusedElement(focused)
        }
        return nil
    }
    private func deepestFocusedElement(_ element: AXUIElement) -> AXUIElement {
        var current = element
        for _ in 0..<8 {
            guard let child = focusedElement(in: current), !CFEqual(child, current) else { break }
            current = child
        }
        return current
    }
    private func focusedElement(in application: AXUIElement) -> AXUIElement? {
        elementAttribute(application, kAXFocusedUIElementAttribute)
    }
    private func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
    private func snapshot(_ element: AXUIElement?) -> InsertionSnapshot {
        InsertionSnapshot(value: element.flatMap { stringAttribute($0, kAXValueAttribute) },
                          selection: element.flatMap { selectionSnapshot($0) })
    }
    private func selectionSnapshot(_ element: AXUIElement) -> SelectionSnapshot? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let value = unsafeBitCast(raw, to: AXValue.self)
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        return SelectionSnapshot(value: stringAttribute(element, kAXValueAttribute), location: range.location, length: range.length)
    }
    private func screenForElement(_ element: AXUIElement) -> NSScreen? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return NSScreen.main }
        var point = CGPoint.zero
        guard AXValueGetValue(unsafeBitCast(raw, to: AXValue.self), .cgPoint, &point), let primary = NSScreen.screens.first else { return NSScreen.main }
        let cocoaPoint = NSPoint(x: point.x, y: primary.frame.maxY - point.y)
        return NSScreen.screens.first { $0.frame.contains(cocoaPoint) } ?? NSScreen.main
    }
}
