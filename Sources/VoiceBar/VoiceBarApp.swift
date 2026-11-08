import AppKit
import Combine
import ServiceManagement
import SwiftUI
import VoiceBarCore

@main
enum VoiceBarApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        #if VOICEBAR_PREVIEW
        if let index = CommandLine.arguments.firstIndex(of: "--export-previews"), CommandLine.arguments.indices.contains(index + 1) {
            do { try PreviewRenderer.export(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])) }
            catch { fputs("Preview export failed: \(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        #endif
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = AppState()
    private var controller: DictationController!
    private var statusItem: NSStatusItem!
    private let settings = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Standard shortcuts remain available when the explicit Settings window is active.
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let root = NSMenuItem()
        root.submenu = appMenu
        mainMenu.addItem(root)
        add("Settings…", action: #selector(showSettings), key: ",", to: appMenu)
        appMenu.addItem(.separator())
        add("Quit lisan", action: #selector(quit), key: "q", to: appMenu)
        NSApp.mainMenu = mainMenu
        controller = DictationController(state: state)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = BrandIcon.menuBarImage()
        statusItem.button?.toolTip = "lisan"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu(menu)
        if CommandLine.arguments.contains("--settings") || !UserDefaults.standard.bool(forKey: "hasShownSetup") {
            UserDefaults.standard.set(true, forKey: "hasShownSetup")
            showSettings()
        }
        #if VOICEBAR_PREVIEW
        if let index = CommandLine.arguments.firstIndex(of: "--preview-state"), CommandLine.arguments.indices.contains(index + 1) {
            let phase = CommandLine.arguments[index + 1]
            state.phase = phase == "listening" ? .listening : phase == "processing" ? .processing : phase == "complete" ? .complete : .idle
            state.amplitude = 0.7
        }
        #endif
    }
    func applicationWillTerminate(_ notification: Notification) { controller.shutdown() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func menuWillOpen(_ menu: NSMenu) { controller.refreshPermissions(); rebuildMenu(menu) }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "lisan", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        let enabled = add("lisan Enabled", action: #selector(toggleEnabled), to: menu)
        enabled.state = state.enabled ? .on : .off
        add("Settings…", action: #selector(showSettings), key: ",", to: menu)
        let login = add("Launch at Login", action: #selector(toggleLogin), to: menu)
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if !state.lastTranscript.isEmpty {
            menu.addItem(.separator())
            add("Copy Last Transcript", action: #selector(copyTranscript), to: menu)
            add("Clear Last Transcript", action: #selector(clearTranscript), to: menu)
        }
        menu.addItem(.separator())
        add("Quit lisan", action: #selector(quit), key: "q", to: menu)
    }
    @discardableResult
    private func add(_ title: String, action: Selector, key: String = "", to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }
    @objc private func toggleEnabled() { state.enabled.toggle() }
    @objc private func showSettings() { settings.show(state: state, controller: controller) }
    @objc private func copyTranscript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.lastTranscript, forType: .string)
    }
    @objc private func clearTranscript() { state.lastTranscript = "" }
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            if SMAppService.mainApp.status == .requiresApproval {
                state.status = "Approve lisan in System Settings → General → Login Items."
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch { controller.showError("Launch at Login: \(error.localizedDescription)") }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
