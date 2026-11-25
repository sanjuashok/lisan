import AppKit
import Combine
import SwiftUI
import VoiceBarCore

final class IndicatorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The overlay belongs to an inactive accessory app while another editor has
/// focus. Its note button must respond to the first click without activation.
final class BarHostingView: NSHostingView<VoiceBarView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class FloatingBar {
    private let panel: IndicatorPanel
    private var screen: NSScreen?
    var onSaveAsNote: (() -> Void)?
    private var subscriptions = Set<AnyCancellable>()
    init(state: AppState) {
        panel = IndicatorPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.contentView = BarHostingView(rootView: VoiceBarView(state: state, onSaveAsNote: { [weak self] in
            self?.onSaveAsNote?()
        }))
        state.$canChooseNote.sink { [weak self] enabled in
            self?.panel.ignoresMouseEvents = !enabled
        }.store(in: &subscriptions)
        state.$phase.dropFirst().sink { [weak self, weak state] phase in
            guard phase.expanded, state?.enabled == true else { return }
            // Another app/Space can obscure or hide the idle panel. Re-present
            // each active state without making the panel key or activating Lisan.
            self?.panel.orderFrontRegardless()
        }.store(in: &subscriptions)
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
    var onSaveAsNote: () -> Void = {}
    private let orange = Color(red: 198 / 255, green: 93 / 255, blue: 50 / 255)
    private let cream = Color(red: 1, green: 244 / 255, blue: 230 / 255)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Capsule().fill(orange)
                .overlay(Capsule().stroke(.white.opacity(state.phase == .listening ? 0.2 : 0), lineWidth: 1))
            if state.phase.expanded {
                HStack(spacing: 8) {
                    Image(systemName: icon).font(.system(size: 12, weight: .medium))
                    Text(label)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(state.phase == .failure ? 2 : 1)
                    Spacer(minLength: 0)
                    if state.phase == .listening {
                        Waveform(amplitude: state.amplitude).frame(width: 46, height: 16).clipped()
                    } else if state.phase == .processing {
                        ProcessingPulse(reduceMotion: reduceMotion).frame(width: 70, height: 16)
                    }
                    if state.phase == .listening && state.canChooseNote {
                        Button(action: onSaveAsNote) {
                            HStack(spacing: 4) {
                                Image(systemName: state.savingAsNote ? "checkmark" : "note.text")
                                Text("Note")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7).frame(height: 24)
                            .background(cream.opacity(state.savingAsNote ? 0.25 : 0.12), in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(state.savingAsNote)
                        .help(state.savingAsNote ? "This dictation will be saved as a note" : "Save as note instead of typing into the focused field")
                        .accessibilityLabel(state.savingAsNote ? "Saving as note" : "Save as note")
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.phase == .idle ? "lisan ready" : label)
    }
    private var icon: String {
        if state.shortcutTestActive && state.phase == .listening { return "keyboard" }
        if state.savingAsNote && state.phase != .failure { return "note.text" }
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
        case .processing: return state.savingAsNote ? "Saving as note" : "Processing…"
        case .complete: return state.completionLabel
        case .failure: return state.failureLabel
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
