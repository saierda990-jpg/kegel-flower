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
        assert(settings.easterEggRemindersEnabled == true)
        assert(settings.kegelReminderInterval == .fortyFive)
        assert(settings.areRemindersDisabledToday == false)

        settings.launchAtLoginEnabled = false
        settings.popupRemindersEnabled = false
        settings.easterEggRemindersEnabled = false
        settings.kegelReminderInterval = .ninety
        settings.disableRemindersForToday()

        let reloaded = KikuKegelSettingsStore(defaults: defaults)
        assert(reloaded.launchAtLoginEnabled == false)
        assert(reloaded.popupRemindersEnabled == false)
        assert(reloaded.easterEggRemindersEnabled == false)
        assert(reloaded.kegelReminderInterval == .ninety)
        assert(reloaded.areRemindersDisabledToday == true)

        reloaded.launchAtLoginEnabled = true
        reloaded.popupRemindersEnabled = true
        reloaded.easterEggRemindersEnabled = true
        reloaded.kegelReminderInterval = .thirty
        reloaded.enableRemindersForToday()

        assert(settings.launchAtLoginEnabled == true)
        assert(settings.popupRemindersEnabled == true)
        assert(settings.easterEggRemindersEnabled == true)
        assert(settings.kegelReminderInterval == .thirty)
        assert(settings.areRemindersDisabledToday == false)
        assert(DailyCheckInStore.slotCount(for: .weekdays, reminderInterval: .thirty) == 22)
        assert(DailyCheckInStore.slotCount(for: .weekdays, reminderInterval: .fortyFive) == 15)
        assert(DailyCheckInStore.slotCount(for: .weekdays, reminderInterval: .ninety) == 8)
        assert(DailyCheckInStore.slotCount(for: .daily, reminderInterval: .sixty) == 13)

        print("AppSettingsTests passed")
    }
}
