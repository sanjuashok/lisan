import AppKit
import ServiceManagement
import SwiftUI
import VoiceBarCore

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    func show(state: AppState, controller: DictationController, tab: AppTab = .settings) {
        controller.cancel()
        controller.refreshPermissions()
        state.selectedTab = tab
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 700),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "lisan"
            window.minSize = NSSize(width: 760, height: 610)
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: LisanWindowView(state: state, controller: controller))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var state: AppState
    let controller: DictationController
    private let orange = Color(red: 198 / 255, green: 93 / 255, blue: 50 / 255)
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private var needsShortcutPermission: Bool {
        state.enabled && !state.shortcutAvailable && !state.inputMonitoringGranted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A LITTLE MORE PERSONAL").font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(orange)
                    Text("Settings").font(.system(size: 32, weight: .semibold)).tracking(-1)
                }.padding(.bottom, 4)

                section("YOUR NOTES") {
                    NoteDestinationSettings(store: state.notes)
                }

                if !state.microphoneGranted || !state.accessibilityGranted || needsShortcutPermission {
                    section {
                        if !state.microphoneGranted {
                            permissionRow("Microphone", subtitle: "Listen only while you hold the shortcut.", buttonTitle: "Allow / Settings") {
                                controller.requestMicrophone()
                            }
                            if !state.accessibilityGranted || needsShortcutPermission { Divider() }
                        }
                        if !state.accessibilityGranted {
                            permissionRow("Accessibility", subtitle: "Insert text at your original cursor.") {
                                controller.requestAccessibility()
                            }
                            if needsShortcutPermission { Divider() }
                        }
                        if needsShortcutPermission {
                            permissionRow("Input Monitoring", subtitle: "Allow global hold and release detection.") {
                                controller.requestInputMonitoring()
                            }
                        }
                        if !state.accessibilityGranted || needsShortcutPermission {
                            Text("Listed as VoiceBar, or already enabled? Remove the old VoiceBar or lisan entry and add this installed copy of lisan, then restart. The renamed app needs its own permissions.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            Button("Show App in Finder") { controller.revealInstalledApp() }
                        }
                    }
                }

                section("YOUR VOICE STAYS HERE") {
                    HStack(alignment: .top) {
                        Image(systemName: state.modelsReady ? "checkmark.seal.fill" : "arrow.down.circle")
                            .foregroundStyle(orange).font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Parakeet · on-device recognition").fontWeight(.medium)
                            Text(state.modelsReady ? "Downloaded and ready for offline dictation." : "One-time model download. Allow several minutes and up to 3 GB of free space.")
                                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if !state.modelsReady {
                            #if VOICEBAR_PREVIEW
                            Text("Preview build").font(.system(size: 11)).foregroundStyle(.secondary)
                            #else
                            Button(state.preparing ? "Preparing…" : "Download") { controller.prepareModels(allowDownload: true) }
                                .disabled(state.preparing)
                            #endif
                        }
                    }
                    if state.preparing { ProgressView(value: state.modelProgress).tint(orange) }
                }

                section("MAKE IT YOURS") {
                    Picker("Hold to dictate", selection: $state.shortcut) {
                        ForEach(WakeShortcut.allCases) { shortcut in Text(shortcut.title).tag(shortcut) }
                    }
                    Text("For Fn / Globe, set “Press 🌐 key to” to “Do Nothing” in System Settings → Keyboard, and turn off any conflicting Dictation shortcut. Escape cancels a recording.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Toggle("Launch at login", isOn: $loginEnabled)
                        .onChange(of: loginEnabled) { _, enabled in
                            guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
                            do {
                                if enabled { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                                loginError = SMAppService.mainApp.status == .requiresApproval ? "Approve lisan in System Settings → General → Login Items." : nil
                            } catch {
                                loginError = error.localizedDescription
                                loginEnabled = SMAppService.mainApp.status == .enabled
                            }
                        }
                    if let loginError { Text(loginError).font(.system(size: 11)).foregroundStyle(.secondary) }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield").foregroundStyle(orange)
                    Text("Audio is kept in memory and discarded after dictation. No accounts, no servers, no audio uploads.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let latency = state.lastLatency {
                    Text(String(format: "Last processing + insertion: %.2f seconds", latency)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                }
                DisclosureGroup("Troubleshooting") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(state.status).textSelection(.enabled)
                        Text(state.lastShortcutEvent).foregroundStyle(.secondary)
                        Text("Microphone: \(state.microphoneGranted ? "allowed" : "missing") · Accessibility: \(state.accessibilityGranted ? "allowed" : "missing") · Input Monitoring: \(state.inputMonitoringGranted ? "allowed" : "missing")")
                            .foregroundStyle(.secondary)
                        Text(state.shortcutAvailable ? "Shortcut listener registered. A detected press above confirms delivery." : "Global shortcut listener is unavailable.")
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Test shortcut") { controller.startShortcutTest() }
                            Button("Check permissions") { controller.refreshPermissions(showFeedback: true) }
                            Button("Restart lisan") { controller.restartForPermissions() }
                                .disabled(state.restarting)
                        }
                        if !state.permissionFeedback.isEmpty {
                            Text(state.permissionFeedback).foregroundStyle(.secondary)
                        }
                        if !state.recentModifierEvents.isEmpty {
                            Text("Recent modifier events · no typed text is recorded").fontWeight(.medium)
                            ForEach(Array(state.recentModifierEvents.enumerated()), id: \.offset) { _, event in
                                Text(event).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                    .font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }
                #if VOICEBAR_PREVIEW
                Text("UI PREVIEW · Speech recognition is not included in this build.")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(orange)
                #endif
            }.frame(maxWidth: 740).frame(maxWidth: .infinity).padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .toggleStyle(.switch)
        .tint(orange)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            controller.refreshPermissions()
            loginEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    private func section<Content: View>(_ title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 12, content: content)
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.05)))
        }
    }
    private func permissionRow(_ title: String, subtitle: String, buttonTitle: String = "Open Settings", action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(buttonTitle, action: action)
        }
    }
}

/// Shared with the offscreen design preview so it shows the actual header.
struct SettingsHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: BrandIcon.artwork)
                .resizable().interpolation(.high).scaledToFit()
                .frame(width: 64, height: 64)
                .accessibilityLabel("lisan waveform planet")
        }
    }
}
