import CoreGraphics
import XCTest
@testable import VoiceBar

@MainActor
final class ShortcutMonitorTests: XCTestCase {
    // Feed the same Core Graphics events delivered to the production callback.
    // Nothing is posted to the user's keyboard session.
    private func sendFn(_ down: Bool, to monitor: ShortcutMonitor) throws {
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 63, keyDown: down))
        event.type = .flagsChanged
        event.flags = down ? .maskSecondaryFn : []
        monitor.receiveSessionEvent(.flagsChanged, event: event)
    }

    private func drainKeyboardQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    func testTwoFnHoldsDeliveredBySessionListenerAlone() async throws {
        let monitor = ShortcutMonitor()
        var transitions: [Bool] = []
        monitor.onHold = { held, scope in
            XCTAssertEqual(scope, .system)
            transitions.append(held)
        }
        for down in [true, false, true, false] {
            try sendFn(down, to: monitor)
        }
        await drainKeyboardQueue()
        XCTAssertEqual(transitions, [true, false, true, false])
    }

    func testInterruptionDropsUndeliveredFnPress() async throws {
        let monitor = ShortcutMonitor()
        var transitions: [Bool] = []
        monitor.onHold = { held, _ in transitions.append(held) }
        try sendFn(true, to: monitor)
        monitor.receiveSessionEvent(.tapDisabledByTimeout, event: try XCTUnwrap(CGEvent(source: nil)))
        await drainKeyboardQueue()
        XCTAssertEqual(transitions, [])
    }

    func testFirstFnHoldAfterTapInterruption() async throws {
        for reason in [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput] {
            let monitor = ShortcutMonitor()
            var actions: [String] = []
            monitor.onHold = { held, _ in actions.append(held ? "start" : "finish") }
            monitor.onCancel = { actions.append("cancel") }
            try sendFn(true, to: monitor)
            await drainKeyboardQueue()

            let notification = try XCTUnwrap(CGEvent(source: nil))
            monitor.receiveSessionEvent(reason, event: notification)
            // Both new edges can arrive before the deferred cancellation runs.
            try sendFn(true, to: monitor)
            try sendFn(false, to: monitor)
            await drainKeyboardQueue()
            XCTAssertEqual(actions, ["start", "cancel", "start", "finish"], "Reason: \(reason)")
        }
    }
}
