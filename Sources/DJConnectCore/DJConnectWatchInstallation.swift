import Foundation

/// AppStorage defaults do not persist a generated value until it is written.
/// Commit these hardware-installation values before any WCSession registration,
/// including when SwiftUI constructs more than one app model during startup.
public enum DJConnectWatchInstallation {
    public static func load(defaults: UserDefaults, makeID: () -> String,
                            makeCode: () -> String) -> (id: String, code: String) {
        let stored = defaults.string(forKey: "stableInstallID")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = stored.flatMap { $0.isEmpty ? nil : $0 } ?? makeID()
        let code = defaults.string(forKey: "pairingCode") ?? makeCode()
        defaults.set(id, forKey: "stableInstallID")
        defaults.set(code, forKey: "pairingCode")
        return (id, code)
    }
}
