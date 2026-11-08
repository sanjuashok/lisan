import AppKit
import ApplicationServices
import VoiceBarCore

@MainActor
final class TextInsertion {
    struct Target {
        let pid: pid_t
        let element: AXUIElement
        let selection: SelectionSnapshot
        let screen: NSScreen?
    }
    enum Result { case inserted, pasteSent }

    func capture() throws -> Target {
        guard AXIsProcessTrusted() else { throw VoiceBarError("Allow VoiceBar in Privacy & Security → Accessibility.") }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let element = focusedElement(pid: app.processIdentifier) else {
            throw VoiceBarError("Place the cursor in an editable text field first.")
        }
        guard stringAttribute(element, kAXSubroleAttribute) != kAXSecureTextFieldSubrole else {
            throw VoiceBarError("VoiceBar does not dictate into password fields.")
        }
        guard let selection = snapshot(element) else {
            throw VoiceBarError("This field does not expose a text cursor. Try another text field.")
        }
        return Target(pid: app.processIdentifier, element: element, selection: selection, screen: screenForElement(element))
    }

    func insert(_ text: String, into target: Target) async throws -> Result {
        try validate(target)
        try Task.checkCancellation()
        // Use the editor's normal paste action. Some web editors acknowledge an
        // AXSelectedText write without updating their actual document/input state.
        let expected = target.selection.valueAfterInserting(text)
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
        guard copied else { throw VoiceBarError("Could not prepare the clipboard. Your transcript remains in the VoiceBar menu.") }
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            throw VoiceBarError("Could not send paste. Copy the last transcript from the VoiceBar menu.")
        }
        down.flags = .maskCommand; up.flags = .maskCommand
        try validate(target)
        try Task.checkCancellation()
        down.post(tap: .cgSessionEventTap); up.post(tap: .cgSessionEventTap)
        // Keep the clipboard available while the editor consumes it. Once paste
        // is dispatched, cancellation must not restore the clipboard prematurely.
        // Never retry a dispatched paste: a delayed editor could insert it twice.
        for attempt in 0..<10 {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { continuation.resume() }
            }
            if attempt >= 4, let expected,
               stringAttribute(target.element, kAXValueAttribute) == expected {
                return .inserted
            }
        }
        if let current = snapshot(target.element), current.matches(target.selection), expected != nil {
            throw VoiceBarError("The app did not accept the paste. Copy the last transcript from the VoiceBar menu.")
        }
        // Some editors do not expose their value, or normalize it on paste.
        // Do not claim verified insertion when we cannot read the result.
        return .pasteSent
    }

    private func validate(_ target: Target) throws {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid,
              let current = focusedElement(pid: target.pid), CFEqual(current, target.element),
              let selection = snapshot(current), target.selection.matches(selection) else {
            throw VoiceBarError("The cursor or text changed. Your transcript is saved in the VoiceBar menu; copy it when ready.")
        }
    }
    private func focusedElement(pid: pid_t) -> AXUIElement? {
        let application = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
    private func snapshot(_ element: AXUIElement) -> SelectionSnapshot? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let value = unsafeBitCast(raw, to: AXValue.self)
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range), range.location >= 0 else { return nil }
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
