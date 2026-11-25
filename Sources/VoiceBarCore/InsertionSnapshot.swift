import Foundation

/// Editors may expose a value, a selection, both, or neither. Keep all evidence
/// available at capture without requiring an AXSelectedTextRange to send paste.
public struct InsertionSnapshot {
    public let value: String?
    public let selection: SelectionSnapshot?

    public init(value: String?, selection: SelectionSnapshot?) {
        self.value = value
        self.selection = selection
    }

    public func matches(_ current: InsertionSnapshot) -> Bool {
        if let value, value != current.value { return false }
        if let selection {
            guard let currentSelection = current.selection,
                  selection.location == currentSelection.location,
                  selection.length == currentSelection.length else { return false }
            if let value = selection.value, value != currentSelection.value { return false }
        }
        return true
    }
}
