import AppKit
import SwiftUI
import VoiceBarCore

final class IndicatorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingBar {
    private let panel: IndicatorPanel
    private var screen: NSScreen?
    init(state: AppState) {
        panel = IndicatorPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: VoiceBarView(state: state))
        position(on: NSScreen.main)
    }

    func position(on target: NSScreen? = nil) {
        screen = target ?? screen ?? NSScreen.main
        guard let screen else { return }
        // Fixed transparent host keeps the pill's center stable throughout its animation.
        panel.setFrame(NSRect(x: screen.visibleFrame.midX - 154,
                              y: screen.visibleFrame.minY + BarGeometry.dockGap - 8,
                              width: 308, height: 50), display: true)
    }
    func setVisible(_ visible: Bool) {
        if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }
}

struct VoiceBarView: View {
    @ObservedObject var state: AppState
    private let orange = Color(red: 198 / 255, green: 93 / 255, blue: 50 / 255)
    private let cream = Color(red: 1, green: 244 / 255, blue: 230 / 255)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Capsule().fill(orange)
                .overlay(Capsule().stroke(.white.opacity(state.phase == .listening ? 0.2 : 0), lineWidth: 1))
            if state.phase.expanded {
                HStack(spacing: 10) {
                    Image(systemName: icon).font(.system(size: 12, weight: .medium))
                    Text(label).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 0)
                    if state.phase == .listening {
                        Waveform(amplitude: state.amplitude).frame(width: 70, height: 16)
                    } else if state.phase == .processing {
                        ProcessingPulse(reduceMotion: reduceMotion).frame(width: 70, height: 16)
                    }
                    Text(state.shortcut.badge)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(cream.opacity(0.13), in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 14).foregroundStyle(cream)
                .transition(.opacity)
            }
        }
        .frame(width: state.phase.expanded ? BarGeometry.activeWidth : BarGeometry.idleWidth,
               height: state.phase.expanded ? BarGeometry.activeHeight : BarGeometry.idleHeight)
        .shadow(color: .black.opacity(state.phase.expanded ? 0.13 : 0.05), radius: state.phase.expanded ? 5 : 2, y: 2)
        .animation(reduceMotion ? nil : .easeOut(duration: BarGeometry.animationDuration), value: state.phase)
        .frame(width: 308, height: 50, alignment: .bottom)
        .offset(y: -8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.phase == .idle ? "lisan ready" : label)
    }
    private var icon: String {
        if state.shortcutTestActive && state.phase == .listening { return "keyboard" }
        switch state.phase {
        case .idle, .listening: return "mic.fill"
        case .processing: return "ellipsis"
        case .complete: return "checkmark"
        case .failure: return "exclamationmark.circle"
        }
    }
    private var label: String {
        if state.shortcutTestActive && state.phase == .listening { return "Shortcut test" }
        switch state.phase {
        case .idle: return ""
        case .listening: return "Listening…"
        case .processing: return "Processing…"
        case .complete: return state.completionLabel
        case .failure: return "Open lisan Settings"
        }
    }
}

private struct Waveform: View {
    let amplitude: Double
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<18, id: \.self) { index in
                let weight = 0.3 + 0.7 * abs(sin(Double(index) * 1.8 + 0.4))
                Capsule().frame(width: 2, height: max(2, 16 * amplitude * weight))
            }
        }
        .animation(.linear(duration: 0.06), value: amplitude)
    }
}

private struct ProcessingPulse: View {
    let reduceMotion: Bool
    @State private var dim = false
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle().frame(width: 3, height: 3).opacity(dim ? 0.3 : 0.85)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.14), value: dim)
            }
        }.onAppear { dim = true }
    }
}
