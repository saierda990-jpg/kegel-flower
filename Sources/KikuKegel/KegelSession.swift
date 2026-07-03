import Foundation

enum ReminderMode: String {
    case idle
    case reminding
    case preparing
    case exercising
    case completing
}

enum KegelPhase: String {
    case contract = "收缩"
    case relax = "放松"
}

struct KegelTiming {
    var reminderInterval: TimeInterval = 45 * 60
    var contractSeconds: Int = 5
    var relaxSeconds: Int = 5
    var cycles: Int = 12
}

final class KegelSession: ObservableObject {
    private let nextReminderStorageKey = "KegelSession.nextReminderAt.v1"

    @Published private(set) var mode: ReminderMode = .idle
    @Published private(set) var phase: KegelPhase = .contract
    @Published private(set) var secondsLeftInPhase: Int = 5
    @Published private(set) var completedCycles: Int = 0
    @Published private(set) var nextReminderAt: Date
    @Published private(set) var transitionText: String = ""

    private(set) var timing = KegelTiming()
    var scheduleMode: ReminderScheduleMode = .weekdays

    var onReminder: (() -> Void)?
    var onTick: (() -> Void)?
    var onFinishExercise: (() -> Void)?

    private var reminderTimer: Timer?
    private var exerciseTimer: Timer?
    private var transitionTimer: Timer?
    private let preparationSteps = ["3", "2", "1", "开始"]
    private var preparationStepIndex = 0

    init() {
        nextReminderAt = UserDefaults.standard.object(forKey: nextReminderStorageKey) as? Date
            ?? Date().addingTimeInterval(timing.reminderInterval)
    }

    var totalCycles: Int {
        timing.cycles
    }

    var totalExerciseSeconds: Int {
        timing.cycles * (timing.contractSeconds + timing.relaxSeconds)
    }

    var remainingExerciseSeconds: Int {
        let cycleSeconds = timing.contractSeconds + timing.relaxSeconds
        let remainingCurrentCycle = secondsLeftInPhase + (phase == .contract ? timing.relaxSeconds : 0)
        let remainingFullCycles = max(0, timing.cycles - completedCycles - 1) * cycleSeconds
        return remainingCurrentCycle + remainingFullCycles
    }

    var shortStatusText: String {
        switch mode {
        case .idle:
            return ""
        case .reminding:
            return ""
        case .preparing, .completing:
            return transitionText
        case .exercising:
            return "\(phase == .contract ? "收" : "放") \(secondsLeftInPhase)s"
        }
    }

    var isExerciseFlowActive: Bool {
        mode == .preparing || mode == .exercising || mode == .completing
    }

    func start() {
        restoreOrScheduleNextReminder()
    }

    func applyScheduleMode(_ mode: ReminderScheduleMode) {
        scheduleMode = mode
        guard self.mode == .idle || self.mode == .reminding else { return }
        restoreOrScheduleNextReminder()
    }

    func applyReminderInterval(_ interval: KegelReminderInterval) {
        timing.reminderInterval = interval.timeInterval
        guard mode == .idle || mode == .reminding else { return }
        scheduleNextReminder(from: Date())
    }

    func triggerReminderNow() {
        guard scheduleMode.isActive(at: Date()) else {
            scheduleNextReminder(from: Date().addingTimeInterval(-timing.reminderInterval))
            return
        }

        reminderTimer?.invalidate()
        reminderTimer = nil
        mode = .reminding
        onReminder?()
        onTick?()
    }

    func startExercise() {
        reminderTimer?.invalidate()
        reminderTimer = nil
        exerciseTimer?.invalidate()
        transitionTimer?.invalidate()
        UserDefaults.standard.removeObject(forKey: nextReminderStorageKey)

        phase = .contract
        secondsLeftInPhase = timing.contractSeconds
        completedCycles = 0
        preparationStepIndex = 0
        transitionText = preparationSteps[preparationStepIndex]
        mode = .preparing
        onTick?()

        transitionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.advancePreparationCue()
        }
    }

    func snooze(minutes: Int) {
        transitionTimer?.invalidate()
        transitionTimer = nil
        exerciseTimer?.invalidate()
        exerciseTimer = nil
        mode = .idle
        transitionText = ""
        scheduleNextReminder(from: Date().addingTimeInterval(TimeInterval(minutes * 60) - timing.reminderInterval))
        onTick?()
    }

    func pauseReminders(until date: Date) {
        reminderTimer?.invalidate()
        reminderTimer = nil
        transitionTimer?.invalidate()
        transitionTimer = nil
        exerciseTimer?.invalidate()
        exerciseTimer = nil
        mode = .idle
        transitionText = ""
        nextReminderAt = date
        persistNextReminderAt()
        let delay = max(1, date.timeIntervalSinceNow)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.triggerReminderNow()
        }
        reminderTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        onTick?()
    }

    func stopAndReschedule() {
        transitionTimer?.invalidate()
        transitionTimer = nil
        exerciseTimer?.invalidate()
        exerciseTimer = nil
        transitionText = "完成"
        mode = .completing
        onFinishExercise?()
        onTick?()

        transitionTimer = Timer.scheduledTimer(withTimeInterval: 1.35, repeats: false) { [weak self] _ in
            self?.finishCompletionCue()
        }
    }

    private func advancePreparationCue() {
        guard mode == .preparing else { return }
        preparationStepIndex += 1
        guard preparationStepIndex < preparationSteps.count else {
            beginExerciseCountdown()
            return
        }

        transitionText = preparationSteps[preparationStepIndex]
        onTick?()
    }

    private func beginExerciseCountdown() {
        guard mode == .preparing else { return }
        transitionTimer?.invalidate()
        transitionTimer = nil
        transitionText = ""
        mode = .exercising
        phase = .contract
        secondsLeftInPhase = timing.contractSeconds
        completedCycles = 0
        onTick?()

        exerciseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.advanceExercise()
        }
    }

    private func finishCompletionCue() {
        guard mode == .completing else { return }
        transitionTimer?.invalidate()
        transitionTimer = nil
        transitionText = ""
        mode = .idle
        scheduleNextReminder(from: Date())
        onTick?()
    }

    private func scheduleNextReminder(from date: Date) {
        reminderTimer?.invalidate()
        let target = scheduleMode.nextReminderDate(after: date, interval: timing.reminderInterval)
        nextReminderAt = target
        persistNextReminderAt()
        let delay = max(1, target.timeIntervalSinceNow)

        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.triggerReminderNow()
        }
        reminderTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func restoreOrScheduleNextReminder() {
        reminderTimer?.invalidate()
        if !scheduleMode.isActive(at: Date()), nextReminderAt <= Date() {
            scheduleNextReminder(from: Date().addingTimeInterval(-timing.reminderInterval))
            return
        }

        if nextReminderAt <= Date() {
            triggerReminderNow()
            return
        }

        let delay = max(1, nextReminderAt.timeIntervalSinceNow)
        persistNextReminderAt()
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.triggerReminderNow()
        }
        reminderTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        onTick?()
    }

    private func persistNextReminderAt() {
        UserDefaults.standard.set(nextReminderAt, forKey: nextReminderStorageKey)
    }

    private func advanceExercise() {
        guard mode == .exercising else { return }

        if secondsLeftInPhase > 1 {
            secondsLeftInPhase -= 1
            onTick?()
            return
        }

        switch phase {
        case .contract:
            phase = .relax
            secondsLeftInPhase = timing.relaxSeconds
        case .relax:
            completedCycles += 1
            if completedCycles >= timing.cycles {
                stopAndReschedule()
                return
            }
            phase = .contract
            secondsLeftInPhase = timing.contractSeconds
        }

        onTick?()
    }
}
