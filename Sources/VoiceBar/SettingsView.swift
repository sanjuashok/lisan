import AppKit
import ServiceManagement
import SwiftUI
import VoiceBarCore

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    func show(state: AppState, controller: DictationController) {
        controller.cancel()
        controller.refreshPermissions()
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 650),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "lisan Settings"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(state: state, controller: controller))
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "waveform").font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.white).frame(width: 54, height: 54)
                        .background(orange, in: RoundedRectangle(cornerRadius: 17))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("A little bar. A clearer thought.").font(.system(size: 20, weight: .semibold))
                        Text("Speak naturally. Keep your flow.").foregroundStyle(.secondary)
                    }
                }

                Text(state.status).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                section("READY WHEN YOU ARE") {
                    permissionRow("Microphone", subtitle: "Listen only while you hold the shortcut.", granted: state.microphoneGranted, buttonTitle: "Allow / Settings") {
                        controller.requestMicrophone()
                    }
                    Divider()
                    permissionRow("Accessibility", subtitle: "Insert text at your original cursor.", granted: state.accessibilityGranted) {
                        controller.requestAccessibility()
                    }
                    if !state.shortcutAvailable {
                        Divider()
                        permissionRow("Input Monitoring", subtitle: "Allow global hold and release detection.", granted: state.inputMonitoringGranted) {
                            controller.requestInputMonitoring()
                        }
                    }
                    HStack {
                        Button("Check Permissions") { controller.refreshPermissions(showFeedback: true) }
                        Button("Restart lisan") { controller.restartForPermissions() }
                            .disabled(state.restarting)
                    }
                    if !state.permissionFeedback.isEmpty {
                        Text(state.permissionFeedback).font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !state.accessibilityGranted || !state.shortcutAvailable {
                        Text("Already enabled in macOS? An app update can leave an old permission entry. Remove lisan from that list and add this installed copy again, then restart.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Button("Show App in Finder") { controller.revealInstalledApp() }
                    }
                    Text(state.shortcutAvailable ? "Global listener installed. Test the shortcut in another app to verify detection." : "Global shortcut access is missing. The shortcut can still be tested while this Settings window is focused.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Button("Test shortcut without recording") { controller.startShortcutTest() }
                    Text(state.lastShortcutEvent).font(.system(size: 11)).foregroundStyle(.secondary)
                    Button("Test text insertion") { controller.startInsertionTest() }
                    Text("After clicking, focus a text field and press the dictation shortcut. Inserts ‘lisan insertion test.’ without using the microphone.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
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
                    Divider()
                    Toggle("Intelligent text cleanup", isOn: $state.smartCleanup)
                    Text(SpeechService.cleanupDescription).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("Cleanup instructions").fontWeight(.medium)
                        Spacer()
                        Button("Reset") { state.cleanupInstructions = "" }
                            .disabled(state.cleanupInstructions.isEmpty)
                    }
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: Binding(
                            get: { state.cleanupInstructions },
                            set: { state.cleanupInstructions = String($0.prefix(CleanupPrompt.maximumCustomLength)) }
                        ))
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        if state.cleanupInstructions.isEmpty {
                            Text("For example: Keep it casual. Use contractions. Avoid semicolons. Don’t add a final period.")
                                .font(.system(size: 12)).foregroundStyle(.tertiary)
                                .padding(.horizontal, 9).padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(height: 100)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12)))
                    .accessibilityLabel("Cleanup instructions")
                    Text("Saved automatically. Used when intelligent cleanup is on and available. Leave blank for the default style. Up to 1,000 characters.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                #if VOICEBAR_PREVIEW
                Text("UI PREVIEW · Speech recognition is not included in this build.")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(orange)
                #endif
            }.padding(26)
        }
        .frame(width: 520, height: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(orange)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            controller.refreshPermissions()
            loginEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12, content: content)
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.05)))
        }
    }
    private func permissionRow(_ title: String, subtitle: String, granted: Bool, buttonTitle: String = "Open Settings", action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label("Allowed", systemImage: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(orange)
            } else {
                Button(buttonTitle, action: action)
            }
        }
    }
}
