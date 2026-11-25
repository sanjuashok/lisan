import Foundation

public enum AppPreferencesMigration {
    public static let marker = "migratedVoiceBarPreferences"
    private static let keys = ["enabled", "shortcut", "smartCleanup", "cleanupInstructions"]

    public static func merged(current: [String: Any], legacy: [String: Any]) -> [String: Any] {
        guard current[marker] as? Bool != true else { return current }
        var result = current
        for key in keys where result[key] == nil {
            result[key] = legacy[key]
        }
        // Do not migrate hasShownSetup: the new identity needs fresh permissions.
        result[marker] = true
        return result
    }

    public static func migrate(bundleIdentifier: String?, defaults: UserDefaults = .standard) {
        let legacyID: String
        switch bundleIdentifier {
        case "app.lisan.mac": legacyID = "app.voicebar.mac"
        case "app.lisan.preview": legacyID = "app.voicebar.preview"
        default: return
        }
        guard let bundleIdentifier else { return }
        let current = defaults.persistentDomain(forName: bundleIdentifier) ?? [:]
        guard current[marker] as? Bool != true else { return }
        let legacy = defaults.persistentDomain(forName: legacyID) ?? [:]
        defaults.setPersistentDomain(merged(current: current, legacy: legacy), forName: bundleIdentifier)
    }
}
