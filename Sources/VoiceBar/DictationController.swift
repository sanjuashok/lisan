import AppKit
import AVFoundation
import Combine
import VoiceBarCore

@MainActor
final class DictationController {
    let state: AppState
    let bar: FloatingBar
    private let recorder = AudioCapture()
    private let speech = SpeechService()
    private let insertion = TextInsertion()
    private let keyboard = ShortcutMonitor()
    private var subscriptions = Set<AnyCancellable>()
    private var target: TextInsertion.Target?
    private var processingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var limitTask: Task<Void, Never>?
    private var setupTask: Task<Void, Never>?
    private var sessionID = UUID()
    private var insertionTestActive = false
    private var observers: [NSObjectProtocol] = []

    init(state: AppState) {
        self.state = state
        bar = FloatingBar(state: state)
        recorder.onAmplitude = { [weak self] amplitude in
            guard let self, self.state.phase == .listening else { return }
            self.state.amplitude = amplitude
        }
        keyboard.onHold = { [weak self] held, scope in
            let origin = scope == .global ? "Global shortcut" : "Shortcut inside lisan"
            self?.state.lastShortcutEvent = "\(origin) detected: \(held ? "holding" : "released")."
            if held { self?.begin() } else { self?.finish() }
        }
        keyboard.onCancel = { [weak self] in self?.cancel() }
        state.$enabled.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] enabled in
            guard let self else { return }
            if !enabled { self.cancel(); self.keyboard.stop(); self.state.shortcutAvailable = false }
            else { self.refreshPermissions() }
            self.bar.setVisible(enabled)
        }.store(in: &subscriptions)
        state.$shortcut.sink { [weak self] shortcut in
            self?.keyboard.reset()
            self?.keyboard.shortcut = shortcut
        }.store(in: &subscriptions)
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.bar.position(on: NSScreen.main) }
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.keyboard.reset() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state.phase == .listening else { return }
                self.cancel()
                self.showError("The microphone changed. Hold the shortcut again to start a new recording.")
            }
        })
        bar.setVisible(state.enabled)
        refreshPermissions()
        prepareModels(allowDownload: false)
    }

    func refreshPermissions(showFeedback: Bool = false) {
        state.microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        state.accessibilityGranted = AXIsProcessTrusted()
        state.inputMonitoringGranted = CGPreflightListenEventAccess()
        if state.enabled {
            state.shortcutAvailable = keyboard.start(reinstall: showFeedback)
        } else {
            state.shortcutAvailable = false
        }
        if showFeedback {
            let time = Date().formatted(date: .omitted, time: .standard)
            if state.microphoneGranted && state.accessibilityGranted && (state.shortcutAvailable || !state.enabled) {
                state.permissionFeedback = "Checked at \(time). Permissions are ready.\(state.enabled ? "" : " Enable lisan from its menu to use dictation.")"
            } else {
                var missing: [String] = []
                if !state.microphoneGranted { missing.append("Microphone") }
                if !state.accessibilityGranted { missing.append("Accessibility") }
                if state.enabled && !state.shortcutAvailable { missing.append("global shortcut access") }
                state.permissionFeedback = "Checked at \(time). Still missing: \(missing.joined(separator: ", ")). Open the corresponding settings below. After changing access, restart lisan."
            }
        }
    }
    func requestMicrophone() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
            openPrivacySettings("Privacy_Microphone", name: "Microphone")
            return
        }
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            state.microphoneGranted = granted
            if !granted { openPrivacySettings("Privacy_Microphone", name: "Microphone") }
            else { refreshPermissions(showFeedback: true) }
        }
    }
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacySettings("Privacy_Accessibility", name: "Accessibility (Device Control and Data Access on newer macOS versions)")
    }
    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        // macOS may decline to show a second request. Always provide a route
        // to the actual controls instead of silently ignoring a false result.
        openPrivacySettings("Privacy_ListenEvent", name: "Input Monitoring")
    }

    private func openPrivacySettings(_ pane: String, name: String) {
        refreshPermissions()
        state.permissionFeedback = "Enable lisan under \(name), then return here and restart lisan. If it is already enabled but access is still missing, remove the old lisan entry and add this installed copy again using Show App in Finder."
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
        if !NSWorkspace.shared.open(url) {
            state.permissionFeedback = "Could not open System Settings. Open it manually, choose Privacy & Security → \(name), and enable lisan."
        }
    }

    func revealInstalledApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    func restartForPermissions() {
        guard !state.restarting else { return }
        state.restarting = true
        cancel()
        keyboard.stop()
        state.shortcutAvailable = false
        // Wait for this process to exit before asking Launch Services to reopen
        // the bundle. Overlapping instances can lose the accessory app's windows.
        // Pass the PID/path as positional arguments, never shell-interpolated text.
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", """
            while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.1; done
            exec /usr/bin/open -n "$2" --args --settings
            """, "lisan-relaunch", String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath]
        do {
            try relaunch.run()
            NSApp.terminate(nil)
        } catch {
            state.restarting = false
            refreshPermissions()
            state.permissionFeedback = "Restart failed: \(error.localizedDescription). Quit lisan from its menu and reopen it from Applications."
        }
    }

    func prepareModels(allowDownload: Bool) {
        #if VOICEBAR_PREVIEW
        state.status = "UI preview: hold the shortcut in Settings to test the bar. Global use requires Input Monitoring. Install the production build for dictation."
        return
        #else
        guard !state.preparing, !state.modelsReady else { return }
        state.preparing = true
        state.status = allowDownload ? "Downloading and preparing Parakeet. Keep lisan open…" : "Checking local speech model…"
        setupTask = Task {
            defer { state.preparing = false }
            do {
                try await speech.prepare(allowDownload: allowDownload) { [weak self] progress in
                    Task { @MainActor [weak self] in self?.state.modelProgress = progress }
                }
                state.modelsReady = true
                state.status = "Ready. Hold \(state.shortcut.title) in a text field to dictate."
            } catch {
                state.status = allowDownload ? "Model setup failed: \(error.localizedDescription)" : "Download the local speech model in Settings to get started."
            }
        }
        #endif
    }

    /// The test deliberately does not open the microphone or insert text.
    func startShortcutTest() {
        cancel()
        state.shortcutTestActive = true
        state.lastShortcutEvent = "Hold \(state.shortcut.title) now. Release to collapse. Escape ends the test."
        state.status = "Shortcut test active. No audio is recorded."
    }

    func startInsertionTest() {
        cancel()
        insertionTestActive = true
        state.status = "Click a text field in another app, then press and release \(state.shortcut.title). lisan will insert ‘lisan insertion test.’ without recording audio. Escape cancels."
    }

    private func begin() {
        guard state.enabled, state.phase != .listening, state.phase != .processing else { return }
        feedbackTask?.cancel()
        #if VOICEBAR_PREVIEW
        state.shortcutTestActive = true
        #endif
        if state.shortcutTestActive {
            bar.position(on: NSScreen.main)
            state.phase = .listening
            state.amplitude = 0
            state.status = "Shortcut detected. Bar test only; no audio is recorded."
            return
        }
        guard state.modelsReady else { showError("Speech model is not ready. Open Settings from the lisan menu."); return }
        do {
            target = try insertion.capture()
            bar.position(on: target?.screen)
            state.amplitude = 0
            state.phase = .listening
            if insertionTestActive { return }
            try recorder.start()
            sessionID = UUID()
            limitTask = Task {
                try? await Task.sleep(nanoseconds: 120_000_000_000)
                if !Task.isCancelled { finish() }
            }
        } catch {
            target = nil
            recorder.cancel()
            showError(error.localizedDescription)
        }
    }

    private func finish() {
        guard state.phase == .listening else { return }
        if state.shortcutTestActive {
            state.shortcutTestActive = false
            state.phase = .idle
            state.status = "Shortcut test passed: press expands, release collapses. No audio was recorded."
            return
        }
        if insertionTestActive, let target {
            insertionTestActive = false
            self.target = nil
            state.phase = .processing
            let id = sessionID
            processingTask = Task {
                do {
                    let result = try await insertion.insert("lisan insertion test.", into: target)
                    guard sessionID == id, !Task.isCancelled else { return }
                    showInsertionResult(result)
                } catch {
                    guard sessionID == id, !Task.isCancelled else { return }
                    showError(error.localizedDescription)
                }
            }
            return
        }
        limitTask?.cancel()
        guard let audio = recorder.stop(), let target else { cancel(); return }
        self.target = nil
        guard audio.duration >= 0.25, audio.peak > 0.003 else {
            state.status = "No speech detected. Hold the shortcut and try again."
            state.phase = .idle
            return
        }
        state.phase = .processing
        state.amplitude = 0
        let id = sessionID
        let intelligent = state.smartCleanup
        let cleanupInstructions = state.cleanupInstructions
        processingTask = Task {
            let start = Date()
            do {
                let raw = try await speech.transcribe(audio)
                try Task.checkCancellation()
                let cleaned = await speech.clean(raw, intelligent: intelligent, instructions: cleanupInstructions)
                try Task.checkCancellation()
                guard sessionID == id else { return }
                guard !cleaned.isEmpty else { throw VoiceBarError("No speech recognized. Try speaking closer to the microphone.") }
                state.lastTranscript = cleaned
                let result = try await insertion.insert(cleaned, into: target)
                guard sessionID == id, !Task.isCancelled else { return }
                state.lastLatency = Date().timeIntervalSince(start)
                showInsertionResult(result)
            } catch is CancellationError { /* A cancelled session must never insert text. */ }
            catch {
                guard sessionID == id, !Task.isCancelled else { return }
                showError(error.localizedDescription)
            }
        }
    }

    func cancel() {
        state.shortcutTestActive = false
        insertionTestActive = false
        sessionID = UUID()
        recorder.cancel()
        processingTask?.cancel(); feedbackTask?.cancel(); limitTask?.cancel()
        target = nil
        state.phase = .idle
        state.amplitude = 0
    }
    func shutdown() { cancel(); keyboard.stop(); setupTask?.cancel() }
    private func showInsertionResult(_ result: TextInsertion.Result) {
        switch result {
        case .inserted:
            state.completionLabel = "Inserted"
            state.status = "Text insertion verified. Ready for the next dictation."
        case .pasteSent:
            state.completionLabel = "Paste sent"
            state.status = "Paste sent, but this editor did not expose a matching result. If nothing appeared, copy the last transcript from the lisan menu."
        }
        state.phase = .complete
        collapse(after: 700_000_000)
    }
    func showError(_ message: String) {
        state.status = message
        state.phase = .failure
        collapse(after: 2_000_000_000)
    }
    private func collapse(after delay: UInt64) {
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(nanoseconds: delay)
            if !Task.isCancelled { state.phase = .idle }
        }
    }
}
