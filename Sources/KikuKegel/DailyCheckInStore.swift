import Foundation

struct DailyCheckInSummary {
    let completedSlots: [Bool]
    let todayCount: Int
    let yesterdayCount: Int

    var totalCount: Int {
        completedSlots.count
    }

    var comparisonText: String {
        let delta = Int(round((Double(todayCount - yesterdayCount) / Double(totalCount)) * 100))
        if delta > 0 {
            return "比昨天 +\(delta)%，真棒"
        }
        if delta < 0 {
            return "比昨天 \(delta)%，再接再厉"
        }
        return "和昨天持平，继续保持"
    }
}

final class DailyCheckInStore {
    static func slotCount(
        for scheduleMode: ReminderScheduleMode,
        reminderInterval: KegelReminderInterval = .fortyFive
    ) -> Int {
        scheduleMode.slotMinutes(interval: reminderInterval.minutes).count
    }

    private let storageKey = "DailyCheckInRecords.v1"
    private let defaults: UserDefaults
    private var records: [String: Set<Int>]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.records = Self.loadRecords(from: defaults, key: storageKey)
    }

    func markCompletion(
        at date: Date = Date(),
        preferredSlotIndex: Int? = nil,
        scheduleMode: ReminderScheduleMode = .weekdays,
        reminderInterval: KegelReminderInterval = .fortyFive
    ) -> Bool {
        let key = dateKey(for: date)
        let count = Self.slotCount(for: scheduleMode, reminderInterval: reminderInterval)
        let slotIndex = normalizedSlotIndex(preferredSlotIndex, count: count)
            ?? nearestSlotIndex(for: date, scheduleMode: scheduleMode, reminderInterval: reminderInterval)
        var slots = records[key, default: []]

        guard !slots.contains(slotIndex) else {
            return false
        }

        slots.insert(slotIndex)
        records[key] = slots
        save()
        return true
    }

    func nearestSlotIndex(
        for date: Date = Date(),
        scheduleMode: ReminderScheduleMode = .weekdays,
        reminderInterval: KegelReminderInterval = .fortyFive
    ) -> Int {
        let slots = slotDates(for: date, scheduleMode: scheduleMode, reminderInterval: reminderInterval)
        guard let firstSlot = slots.first, let lastSlot = slots.last else {
            return 0
        }

        if date <= firstSlot {
            return 0
        }
        if date >= lastSlot {
            return max(0, slots.count - 1)
        }

        var nearestIndex = 0
        var nearestDistance = abs(date.timeIntervalSince(firstSlot))
        for (index, slotDate) in slots.enumerated().dropFirst() {
            let distance = abs(date.timeIntervalSince(slotDate))
            if distance < nearestDistance {
                nearestIndex = index
                nearestDistance = distance
            }
        }
        return nearestIndex
    }

    func summary(
        for date: Date = Date(),
        scheduleMode: ReminderScheduleMode = .weekdays,
        reminderInterval: KegelReminderInterval = .fortyFive
    ) -> DailyCheckInSummary {
        let todayKey = dateKey(for: date)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let yesterdayKey = dateKey(for: yesterday)
        let todaySlots = records[todayKey, default: []]
        let yesterdaySlots = records[yesterdayKey, default: []]
        let count = Self.slotCount(for: scheduleMode, reminderInterval: reminderInterval)
        let completedSlots = (0..<count).map { todaySlots.contains($0) }

        return DailyCheckInSummary(
            completedSlots: completedSlots,
            todayCount: todaySlots.filter { $0 < count }.count,
            yesterdayCount: yesterdaySlots.filter { $0 < count }.count
        )
    }

    private func slotDates(
        for date: Date,
        scheduleMode: ReminderScheduleMode,
        reminderInterval: KegelReminderInterval
    ) -> [Date] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return scheduleMode.slotMinutes(interval: reminderInterval.minutes).compactMap { minute in
            calendar.date(byAdding: .minute, value: minute, to: startOfDay)
        }
    }

    private func normalizedSlotIndex(_ index: Int?, count: Int) -> Int? {
        guard let index else { return nil }
        return min(max(index, 0), max(0, count - 1))
    }

    private func dateKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func save() {
        let encodedRecords = records.mapValues { Array($0).sorted() }
        guard let data = try? JSONEncoder().encode(encodedRecords) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadRecords(from defaults: UserDefaults, key: String) -> [String: Set<Int>] {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([String: [Int]].self, from: data)
        else {
            return [:]
        }

        return decoded.mapValues { indexes in
            Set(indexes.filter { 0..<64 ~= $0 })
        }
    }
}
