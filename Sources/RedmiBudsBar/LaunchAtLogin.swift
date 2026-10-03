import Foundation
import ServiceManagement

enum LaunchAtLogin {
    private static let configuredKey = "didApplyLaunchAtLoginDefault"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Enables launch at login the first time the app runs. Later changes by the user are respected.
    static func applyDefaultOnFirstRun() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: configuredKey) else { return }
        defaults.set(true, forKey: configuredKey)
        setEnabled(true)
    }
}
