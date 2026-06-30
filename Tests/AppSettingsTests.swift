import Foundation

@main
struct AppSettingsTests {
    static func main() {
        let suiteName = "KikuKegel.AppSettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated defaults suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = KikuKegelSettingsStore(defaults: defaults)

        assert(settings.launchAtLoginEnabled == true)
        assert(settings.popupRemindersEnabled == true)

        settings.launchAtLoginEnabled = false
        settings.popupRemindersEnabled = false

        let reloaded = KikuKegelSettingsStore(defaults: defaults)
        assert(reloaded.launchAtLoginEnabled == false)
        assert(reloaded.popupRemindersEnabled == false)

        reloaded.launchAtLoginEnabled = true
        reloaded.popupRemindersEnabled = true

        assert(settings.launchAtLoginEnabled == true)
        assert(settings.popupRemindersEnabled == true)

        print("AppSettingsTests passed")
    }
}
