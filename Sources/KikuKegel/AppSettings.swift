import Foundation
import ServiceManagement

final class KikuKegelSettingsStore {
    private enum Key {
        static let launchAtLoginEnabled = "Settings.launchAtLoginEnabled.v1"
        static let popupRemindersEnabled = "Settings.popupRemindersEnabled.v1"
        static let cachedUpdateVersion = "Settings.cachedUpdateVersion.v1"
        static let cachedUpdateURL = "Settings.cachedUpdateURL.v1"
        static let lastUpdateCheckAt = "Settings.lastUpdateCheckAt.v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var launchAtLoginEnabled: Bool {
        get { bool(forKey: Key.launchAtLoginEnabled, defaultValue: true) }
        set { defaults.set(newValue, forKey: Key.launchAtLoginEnabled) }
    }

    var popupRemindersEnabled: Bool {
        get { bool(forKey: Key.popupRemindersEnabled, defaultValue: true) }
        set { defaults.set(newValue, forKey: Key.popupRemindersEnabled) }
    }

    var cachedUpdateVersion: String? {
        get { defaults.string(forKey: Key.cachedUpdateVersion) }
        set { defaults.set(newValue, forKey: Key.cachedUpdateVersion) }
    }

    var cachedUpdateURL: String? {
        get { defaults.string(forKey: Key.cachedUpdateURL) }
        set { defaults.set(newValue, forKey: Key.cachedUpdateURL) }
    }

    var lastUpdateCheckAt: Date? {
        get { defaults.object(forKey: Key.lastUpdateCheckAt) as? Date }
        set { defaults.set(newValue, forKey: Key.lastUpdateCheckAt) }
    }

    private func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }
}

enum LaunchAtLoginController {
    static func apply(enabled: Bool) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }

        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Unable to update launch at login setting: \(error.localizedDescription)")
        }
    }
}
