import Foundation
import ServiceManagement

enum ReminderScheduleMode: String, CaseIterable {
    case weekdays
    case daily

    var title: String {
        switch self {
        case .weekdays:
            return "工作日 9:00-20:00"
        case .daily:
            return "每天 9:00-22:00"
        }
    }

    var startMinute: Int {
        9 * 60
    }

    var endMinute: Int {
        switch self {
        case .weekdays:
            return 20 * 60
        case .daily:
            return 22 * 60
        }
    }

    func isActiveDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .weekdays:
            let weekday = calendar.component(.weekday, from: date)
            return weekday != 1 && weekday != 7
        case .daily:
            return true
        }
    }

    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isActiveDay(date, calendar: calendar) else { return false }
        let minute = Self.minuteOfDay(for: date, calendar: calendar)
        return minute >= startMinute && minute < endMinute
    }

    func nextActiveStart(after date: Date, calendar: Calendar = .current) -> Date {
        for offset in 0...14 {
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)),
                isActiveDay(day, calendar: calendar),
                let start = Self.date(on: day, minuteOfDay: startMinute, calendar: calendar)
            else {
                continue
            }

            if start > date {
                return start
            }
        }

        return date.addingTimeInterval(24 * 60 * 60)
    }

    func nextReminderDate(after date: Date, interval: TimeInterval, calendar: Calendar = .current) -> Date {
        let candidate = date.addingTimeInterval(interval)
        guard isActive(at: candidate, calendar: calendar) else {
            return nextActiveStart(after: candidate, calendar: calendar)
        }
        return candidate
    }

    func slotMinutes(interval: Int) -> [Int] {
        guard interval > 0, startMinute < endMinute else { return [] }
        var values: [Int] = []
        var minute = startMinute
        while minute < endMinute {
            values.append(minute)
            minute += interval
        }
        return values
    }

    private static func minuteOfDay(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func date(on day: Date, minuteOfDay: Int, calendar: Calendar) -> Date? {
        calendar.date(
            byAdding: .minute,
            value: minuteOfDay,
            to: calendar.startOfDay(for: day)
        )
    }
}

enum KegelReminderInterval: Int, CaseIterable {
    case thirty = 30
    case fortyFive = 45
    case sixty = 60
    case ninety = 90

    var title: String {
        switch self {
        case .thirty:
            return "30分钟"
        case .fortyFive:
            return "45分钟（推荐）"
        case .sixty:
            return "60分钟"
        case .ninety:
            return "90分钟"
        }
    }

    var minutes: Int {
        rawValue
    }

    var timeInterval: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}

final class KikuKegelSettingsStore {
    private enum Key {
        static let launchAtLoginEnabled = "Settings.launchAtLoginEnabled.v1"
        static let popupRemindersEnabled = "Settings.popupRemindersEnabled.v1"
        static let easterEggRemindersEnabled = "Settings.easterEggRemindersEnabled.v1"
        static let reminderScheduleMode = "Settings.reminderScheduleMode.v1"
        static let kegelReminderInterval = "Settings.kegelReminderInterval.v1"
        static let remindersDisabledDate = "Settings.remindersDisabledDate.v1"
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

    var easterEggRemindersEnabled: Bool {
        get { bool(forKey: Key.easterEggRemindersEnabled, defaultValue: true) }
        set { defaults.set(newValue, forKey: Key.easterEggRemindersEnabled) }
    }

    var reminderScheduleMode: ReminderScheduleMode {
        get {
            defaults.string(forKey: Key.reminderScheduleMode)
                .flatMap(ReminderScheduleMode.init(rawValue:)) ?? .weekdays
        }
        set { defaults.set(newValue.rawValue, forKey: Key.reminderScheduleMode) }
    }

    var kegelReminderInterval: KegelReminderInterval {
        get {
            let saved = defaults.integer(forKey: Key.kegelReminderInterval)
            return KegelReminderInterval(rawValue: saved) ?? .fortyFive
        }
        set { defaults.set(newValue.rawValue, forKey: Key.kegelReminderInterval) }
    }

    var areRemindersDisabledToday: Bool {
        remindersDisabledDateKey == Self.dateKey(for: Date())
    }

    func disableRemindersForToday() {
        remindersDisabledDateKey = Self.dateKey(for: Date())
    }

    func enableRemindersForToday() {
        remindersDisabledDateKey = nil
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

    private var remindersDisabledDateKey: String? {
        get { defaults.string(forKey: Key.remindersDisabledDate) }
        set { defaults.set(newValue, forKey: Key.remindersDisabledDate) }
    }

    private func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    private static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
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
