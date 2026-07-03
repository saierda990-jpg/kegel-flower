import Combine
import Foundation

struct PetStatusSnapshot {
    let fullness: Double
    let hydration: Double
    let energy: Double
    let toilet: Double
    let exercise: Double
    let hydrationHint: String
    let toiletHint: String
    let activityHint: String
    let hydrationDetail: String
    let exerciseDetail: String
    let level: Int
    let experience: Int
    let moodText: String
}

struct PetCareRecordResult {
    let didChange: Bool
    let message: String?
}

final class PetStatusStore: ObservableObject {
    @Published private(set) var revision = 0

    private enum CareKind {
        case feed
        case drink
        case rest
        case toilet
    }

    private struct State: Codable {
        var completedFeedSlotsByDay: [String: [Int]]
        var completedDrinkSlotsByDay: [String: [Int]]
        var completedRestSlotsByDay: [String: [Int]]
        var completedToiletSlotsByDay: [String: [Int]]
        var feedBonusByDay: [String: Double]
        var exerciseCount: Int
        var feedCount: Int
        var feedSnackExperience: Int
        var drinkCount: Int
        var restCount: Int
        var toiletCount: Int
        var accumulatedWellnessSeconds: TimeInterval
        var wellnessStartedAt: Date?

        static let empty = State(
            completedFeedSlotsByDay: [:],
            completedDrinkSlotsByDay: [:],
            completedRestSlotsByDay: [:],
            completedToiletSlotsByDay: [:],
            feedBonusByDay: [:],
            exerciseCount: 0,
            feedCount: 0,
            feedSnackExperience: 0,
            drinkCount: 0,
            restCount: 0,
            toiletCount: 0,
            accumulatedWellnessSeconds: 0,
            wellnessStartedAt: nil
        )

        init(
            completedFeedSlotsByDay: [String: [Int]],
            completedDrinkSlotsByDay: [String: [Int]],
            completedRestSlotsByDay: [String: [Int]],
            completedToiletSlotsByDay: [String: [Int]],
            feedBonusByDay: [String: Double],
            exerciseCount: Int,
            feedCount: Int,
            feedSnackExperience: Int,
            drinkCount: Int,
            restCount: Int,
            toiletCount: Int,
            accumulatedWellnessSeconds: TimeInterval,
            wellnessStartedAt: Date?
        ) {
            self.completedFeedSlotsByDay = completedFeedSlotsByDay
            self.completedDrinkSlotsByDay = completedDrinkSlotsByDay
            self.completedRestSlotsByDay = completedRestSlotsByDay
            self.completedToiletSlotsByDay = completedToiletSlotsByDay
            self.feedBonusByDay = feedBonusByDay
            self.exerciseCount = exerciseCount
            self.feedCount = feedCount
            self.feedSnackExperience = feedSnackExperience
            self.drinkCount = drinkCount
            self.restCount = restCount
            self.toiletCount = toiletCount
            self.accumulatedWellnessSeconds = accumulatedWellnessSeconds
            self.wellnessStartedAt = wellnessStartedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            completedFeedSlotsByDay = try container.decodeIfPresent([String: [Int]].self, forKey: .completedFeedSlotsByDay) ?? [:]
            completedDrinkSlotsByDay = try container.decodeIfPresent([String: [Int]].self, forKey: .completedDrinkSlotsByDay) ?? [:]
            completedRestSlotsByDay = try container.decodeIfPresent([String: [Int]].self, forKey: .completedRestSlotsByDay) ?? [:]
            completedToiletSlotsByDay = try container.decodeIfPresent([String: [Int]].self, forKey: .completedToiletSlotsByDay) ?? [:]
            feedBonusByDay = try container.decodeIfPresent([String: Double].self, forKey: .feedBonusByDay) ?? [:]
            exerciseCount = try container.decodeIfPresent(Int.self, forKey: .exerciseCount) ?? 0
            feedCount = try container.decodeIfPresent(Int.self, forKey: .feedCount) ?? 0
            feedSnackExperience = try container.decodeIfPresent(Int.self, forKey: .feedSnackExperience) ?? 0
            drinkCount = try container.decodeIfPresent(Int.self, forKey: .drinkCount) ?? 0
            restCount = try container.decodeIfPresent(Int.self, forKey: .restCount) ?? 0
            toiletCount = try container.decodeIfPresent(Int.self, forKey: .toiletCount) ?? 0
            accumulatedWellnessSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .accumulatedWellnessSeconds) ?? 0
            wellnessStartedAt = try container.decodeIfPresent(Date.self, forKey: .wellnessStartedAt)
        }
    }

    private let storageKey = "PetStatus.v1"
    private let defaults: UserDefaults
    private var state: State
    var scheduleMode: ReminderScheduleMode = .weekdays

    private let feedSlotCount = 5
    private let drinkSlotCount = 10
    private let restSlotCount = 14
    private let toiletSlotCount = 5
    private let feedRepeatBonusStep = 0.02
    private let feedRepeatBonusLimit = 1.0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.state = Self.loadState(from: defaults, key: storageKey)
    }

    func applyScheduleMode(_ mode: ReminderScheduleMode) {
        scheduleMode = mode
        revision += 1
    }

    func recordExercise(at date: Date = Date()) {
        updateWellnessTracking(at: date)
        state.exerciseCount += 1
        save()
    }

    func recordFeed(at date: Date = Date()) -> PetCareRecordResult {
        updateWellnessTracking(at: date)
        let key = dayKey(for: date)
        var slots = completedSlots(kind: .feed, dayKey: key)

        switch targetSlotStatus(kind: .feed, completedSlots: slots, at: date) {
        case .ready(let slot):
            slots.insert(slot)
            setCompletedSlots(slots, kind: .feed, dayKey: key)
            state.feedCount += 1
        case .notDue, .alreadyDone:
            _ = addFeedRepeatBonus(dayKey: key)
        }

        updateWellnessTracking(at: date)
        save()
        return PetCareRecordResult(didChange: true, message: nil)
    }

    func recordDrink(at date: Date = Date()) -> PetCareRecordResult {
        updateWellnessTracking(at: date)
        let result = recordSlot(kind: .drink, at: date)
        if result.didChange {
            state.drinkCount += 1
        }
        updateWellnessTracking(at: date)
        save()
        return result
    }

    func recordRest(at date: Date = Date()) -> PetCareRecordResult {
        updateWellnessTracking(at: date)
        let result = recordSlot(kind: .rest, at: date)
        if result.didChange {
            state.restCount += 1
        }
        updateWellnessTracking(at: date)
        save()
        return result
    }

    func recordToilet(at date: Date = Date()) -> PetCareRecordResult {
        updateWellnessTracking(at: date)
        let result = recordSlot(kind: .toilet, at: date)
        if result.didChange {
            state.toiletCount += 1
        }
        updateWellnessTracking(at: date)
        save()
        return result
    }

    func snapshot(
        todayExerciseCount: Int,
        exerciseSlotCount: Int,
        at date: Date = Date()
    ) -> PetStatusSnapshot {
        updateWellnessTracking(at: date)

        let fullness = feedProgress(at: date)
        let hydration = dailyProgress(kind: .drink, at: date)
        let energy = dailyProgress(kind: .rest, at: date)
        let toilet = dailyProgress(kind: .toilet, at: date)
        let drinkCompleted = completedSlots(kind: .drink, dayKey: dayKey(for: date)).count
        let suggestedDrinkML = slotCount(kind: .drink) * 200
        let completedDrinkML = min(slotCount(kind: .drink), drinkCompleted) * 200
        let exercise = min(1, Double(todayExerciseCount) / Double(max(1, exerciseSlotCount)))
        let wellnessSeconds = effectiveWellnessSeconds(at: date)
        let experience = state.exerciseCount * 18
            + state.feedCount * 3
            + state.drinkCount * 3
            + state.restCount * 2
            + state.toiletCount * 2
            + Int(wellnessSeconds / 600) * 2
        let level = min(99, max(1, experience / 60 + 1))
        let average = (fullness + hydration + exercise) / 3

        return PetStatusSnapshot(
            fullness: fullness,
            hydration: hydration,
            energy: energy,
            toilet: toilet,
            exercise: exercise,
            hydrationHint: "饮水\(completedDrinkML)/\(suggestedDrinkML)ml \(nextCareText(kind: .drink, at: date))",
            toiletHint: nextCareText(kind: .toilet, at: date),
            activityHint: nextCareText(kind: .rest, at: date),
            hydrationDetail: "\(completedDrinkML)/\(suggestedDrinkML)ml",
            exerciseDetail: "\(todayExerciseCount)/\(exerciseSlotCount)",
            level: level,
            experience: experience,
            moodText: moodText(for: average)
        )
    }

    private func recordSlot(
        kind: CareKind,
        allowsRepeatBonus: Bool = false,
        at date: Date
    ) -> PetCareRecordResult {
        let key = dayKey(for: date)
        var slots = completedSlots(kind: kind, dayKey: key)

        switch targetSlotStatus(kind: kind, completedSlots: slots, at: date) {
        case .ready(let slot):
            slots.insert(slot)
            setCompletedSlots(slots, kind: kind, dayKey: key)
            return PetCareRecordResult(didChange: true, message: nil)
        case .notDue:
            return PetCareRecordResult(didChange: false, message: notDueMessage(for: kind, at: date))
        case .alreadyDone:
            if allowsRepeatBonus, addFeedRepeatBonus(dayKey: key) {
                return PetCareRecordResult(didChange: true, message: nil)
            }
            return PetCareRecordResult(didChange: false, message: alreadyDoneMessage(for: kind, at: date))
        }
    }

    private enum SlotStatus {
        case ready(Int)
        case notDue
        case alreadyDone
    }

    private func targetSlotStatus(kind: CareKind, completedSlots: Set<Int>, at date: Date) -> SlotStatus {
        let count = slotCount(kind: kind)
        guard let latestIndex = latestAvailableSlotIndex(kind: kind, at: date) else {
            return .notDue
        }
        let currentSlot = max(0, min(count - 1, latestIndex))

        if !completedSlots.contains(currentSlot) {
            return .ready(currentSlot)
        }

        return .alreadyDone
    }

    private func addFeedRepeatBonus(dayKey: String) -> Bool {
        let currentBonus = state.feedBonusByDay[dayKey] ?? 0
        guard currentBonus < feedRepeatBonusLimit else {
            return false
        }
        state.feedBonusByDay[dayKey] = min(feedRepeatBonusLimit, currentBonus + feedRepeatBonusStep)
        return true
    }

    private func notDueMessage(for kind: CareKind, at date: Date) -> String {
        switch kind {
        case .feed:
            return "还没到饭点，晚点再喂会更有效"
        case .drink:
            return nextCareText(kind: .drink, at: date)
        case .rest:
            return nextCareText(kind: .rest, at: date)
        case .toilet:
            return nextCareText(kind: .toilet, at: date)
        }
    }

    private func alreadyDoneMessage(for kind: CareKind, at date: Date) -> String {
        switch kind {
        case .feed:
            return "这一轮已经喂过啦，等下个饭点吧"
        case .drink:
            return nextCareText(kind: .drink, at: date)
        case .rest:
            return nextCareText(kind: .rest, at: date)
        case .toilet:
            return nextCareText(kind: .toilet, at: date)
        }
    }

    private func nextCareText(kind: CareKind, at date: Date) -> String {
        switch nextCareTiming(kind: kind, at: date) {
        case .ready:
            switch kind {
            case .feed:
                return "该吃饭了"
            case .drink:
                return "该喝水了"
            case .rest:
                return "该活动了"
            case .toilet:
                return "该如厕了"
            }
        case .waiting(let minutes):
            switch kind {
            case .feed:
                return "吃饭还剩\(minutes)分钟"
            case .drink:
                return "喝水还剩\(minutes)分钟"
            case .rest:
                return "活动还剩\(minutes)分钟"
            case .toilet:
                return "如厕还剩\(minutes)分钟"
            }
        case .finished:
            switch kind {
            case .feed:
                return "今日已喂饱"
            case .drink:
                return "今日水分完成"
            case .rest:
                return "今日活力完成"
            case .toilet:
                return "今日如厕完成"
            }
        }
    }

    private enum NextCareTiming {
        case ready
        case waiting(Int)
        case finished
    }

    private func nextCareTiming(kind: CareKind, at date: Date) -> NextCareTiming {
        let minutes = slotMinutes(kind: kind)
        guard let firstMinute = minutes.first else {
            return .finished
        }

        let minute = minuteOfDay(for: date)
        let key = dayKey(for: date)
        let completed = completedSlots(kind: kind, dayKey: key)

        if minute < firstMinute {
            return .waiting(firstMinute - minute)
        }

        guard let currentIndex = latestSlotIndex(in: minutes, minuteOfDay: minute) else {
            return .waiting(firstMinute - minute)
        }

        let clampedIndex = min(max(currentIndex, 0), minutes.count - 1)
        if !completed.contains(clampedIndex) {
            return .ready
        }

        let nextIndex = clampedIndex + 1
        guard nextIndex < minutes.count else {
            return .finished
        }

        return .waiting(max(1, minutes[nextIndex] - minute))
    }

    private func latestAvailableSlotIndex(kind: CareKind, at date: Date) -> Int? {
        let minute = minuteOfDay(for: date)
        switch kind {
        case .feed:
            return latestSlotIndex(in: slotMinutes(kind: kind), minuteOfDay: minute)
        case .drink:
            return latestSlotIndex(in: slotMinutes(kind: kind), minuteOfDay: minute)
        case .rest:
            return latestSlotIndex(in: slotMinutes(kind: kind), minuteOfDay: minute)
        case .toilet:
            return latestSlotIndex(in: slotMinutes(kind: kind), minuteOfDay: minute)
        }
    }

    private func slotMinutes(kind: CareKind) -> [Int] {
        switch kind {
        case .feed:
            return [10 * 60, 11 * 60 + 30, 14 * 60 + 45, 17 * 60 + 30, 19 * 60 + 30]
                .filter { $0 >= scheduleMode.startMinute && $0 < scheduleMode.endMinute }
        case .drink:
            return evenlySpacedSlots(count: drinkSlotCount)
        case .rest:
            return scheduleMode.slotMinutes(interval: 45)
        case .toilet:
            return scheduleMode.slotMinutes(interval: 120)
        }
    }

    private func evenlySpacedSlots(count: Int) -> [Int] {
        guard count > 1 else { return [scheduleMode.startMinute] }
        let start = scheduleMode.startMinute
        let last = max(start, scheduleMode.endMinute - 60)
        let span = max(0, last - start)
        return (0..<count).map { index in
            start + Int(round(Double(span) * Double(index) / Double(count - 1)))
        }
    }

    private func latestSlotIndex(in slots: [Int], minuteOfDay: Int) -> Int? {
        var index: Int?
        for (slotIndex, slotMinute) in slots.enumerated() where minuteOfDay >= slotMinute {
            index = slotIndex
        }
        return index
    }

    private func dailyProgress(kind: CareKind, at date: Date) -> Double {
        let key = dayKey(for: date)
        let completed = completedSlots(kind: kind, dayKey: key).count
        return min(1, Double(completed) / Double(slotCount(kind: kind)))
    }

    private func feedProgress(at date: Date) -> Double {
        let key = dayKey(for: date)
        return min(1, dailyProgress(kind: .feed, at: date) + (state.feedBonusByDay[key] ?? 0))
    }

    private func slotCount(kind: CareKind) -> Int {
        switch kind {
        case .feed:
            return slotMinutes(kind: .feed).count
        case .drink:
            return slotMinutes(kind: .drink).count
        case .rest:
            return slotMinutes(kind: .rest).count
        case .toilet:
            return slotMinutes(kind: .toilet).count
        }
    }

    private func completedSlots(kind: CareKind, dayKey: String) -> Set<Int> {
        switch kind {
        case .feed:
            return Set(state.completedFeedSlotsByDay[dayKey] ?? [])
        case .drink:
            return Set(state.completedDrinkSlotsByDay[dayKey] ?? [])
        case .rest:
            return Set(state.completedRestSlotsByDay[dayKey] ?? [])
        case .toilet:
            return Set(state.completedToiletSlotsByDay[dayKey] ?? [])
        }
    }

    private func setCompletedSlots(_ slots: Set<Int>, kind: CareKind, dayKey: String) {
        let values = Array(slots).sorted()
        switch kind {
        case .feed:
            state.completedFeedSlotsByDay[dayKey] = values
        case .drink:
            state.completedDrinkSlotsByDay[dayKey] = values
        case .rest:
            state.completedRestSlotsByDay[dayKey] = values
        case .toilet:
            state.completedToiletSlotsByDay[dayKey] = values
        }
    }

    private func updateWellnessTracking(at date: Date) {
        if isFullWellness(at: date) {
            if state.wellnessStartedAt == nil {
                state.wellnessStartedAt = date
            }
            return
        }

        if let startedAt = state.wellnessStartedAt {
            let endOfStartedDay = Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: Calendar.current.startOfDay(for: startedAt)
            ) ?? date
            let cappedEnd = min(date, endOfStartedDay)
            state.accumulatedWellnessSeconds += max(0, cappedEnd.timeIntervalSince(startedAt))
            state.wellnessStartedAt = nil
        }
    }

    private func effectiveWellnessSeconds(at date: Date) -> TimeInterval {
        guard let startedAt = state.wellnessStartedAt, isFullWellness(at: date) else {
            return state.accumulatedWellnessSeconds
        }
        return state.accumulatedWellnessSeconds + max(0, date.timeIntervalSince(startedAt))
    }

    private func isFullWellness(at date: Date) -> Bool {
        dailyProgress(kind: .feed, at: date) >= 0.95
            && dailyProgress(kind: .drink, at: date) >= 0.95
            && dailyProgress(kind: .rest, at: date) >= 0.95
            && dailyProgress(kind: .toilet, at: date) >= 0.95
    }

    private func moodText(for average: Double) -> String {
        if average >= 0.86 {
            return "状态很好"
        }
        if average >= 0.68 {
            return "精神不错"
        }
        if average >= 0.50 {
            return "还不错"
        }
        if average >= 0.30 {
            return "有点蔫了"
        }
        if average >= 0.14 {
            return "需要照顾一下"
        }
        return "快没电了"
    }

    private func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        defaults.set(data, forKey: storageKey)
        revision += 1
    }

    private static func loadState(from defaults: UserDefaults, key: String) -> State {
        guard
            let data = defaults.data(forKey: key),
            let state = try? JSONDecoder().decode(State.self, from: data)
        else {
            return .empty
        }

        return state
    }
}
