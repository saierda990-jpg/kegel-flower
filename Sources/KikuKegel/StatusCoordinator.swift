import AppKit
import Combine
import SwiftUI

private struct PetNeed {
    let key: String
    let icon: String
    let title: String
    let kind: PetCareKind
}

private enum PetCareKind {
    case food
    case drink
}

private struct PendingToast {
    let title: String
    let subtitle: String
    let systemImageName: String?
    let layout: ToastLayout
    let duration: TimeInterval
    let action: (() -> Void)?
    let primaryButtonTitle: String?
    let primaryAction: (() -> Void)?
    let secondaryButtonTitle: String?
    let secondaryAction: (() -> Void)?
    let timeoutAction: (() -> Void)?
}

final class StatusCoordinator: NSObject {
    private let compactStatusItemLength: CGFloat = 24
    private let exerciseStatusItemLength: CGFloat = 66
    private let statusItem = NSStatusBar.system.statusItem(withLength: 24)
    private let session = KegelSession()
    private let popover = NSPopover()
    private let actionPopover = NSPopover()
    private let reminderToast = ToastBubbleWindow()
    private let checkInStore = DailyCheckInStore()
    private let petStatusStore = PetStatusStore()
    private let settings = KikuKegelSettingsStore()
    private let updateChecker = GitHubUpdateChecker()
    private let popoverNoticeStore = PopoverNoticeStore()
    private let riceFeedAnimationWindow = RiceFeedAnimationWindow()
    private let petNeedBubbleWindow = PetNeedBubbleWindow()
    private let fedPetNeedStorageKey = "PetNeeds.fed.v1"
    private let fishToastStorageKey = "PetFishToast.shownSlots.v2"
    private let toiletToastStorageKey = "PetToiletToast.shownSlots.v2"
    private let candyToastStorageKey = "PetCandyToast.shownSlots.v1"
    private let walkToastStorageKey = "PetWalkToast.shownSlots.v1"
    private let petNeedAfterAmbientDelay: TimeInterval = 5 * 60
    private let ambientAfterPetNeedDelay: TimeInterval = 5 * 60
    private let ambientAfterAmbientDelay: TimeInterval = 10 * 60
    private var overlayTestStatusItem: NSStatusItem?

    private var iconStyle: FlowerIconStyle
    private var iconAnimationTimer: Timer?
    private var eyeTimer: Timer?
    private var toastDismissTimer: Timer?
    private var toastSequenceTimer: Timer?
    private var activeToast: PendingToast?
    private var pendingToasts: [PendingToast] = []
    private var suppressToastContinueOnClose = false
    private var pendingToastPresentation: DispatchWorkItem?
    private var nextPetNeedToastAllowedAt = Date.distantPast
    private var nextAmbientToastAllowedAt = Date.distantPast
    private var pulseStartDate = Date()
    private var lastRenderedPhase: KegelPhase = .contract
    private var nextBlinkAt = Date()
    private var blinkStartDate: Date?
    private var eyeLookOffset = CGPoint.zero
    private var iconTiltDegrees: CGFloat = 0
    private var reminderStartDate: Date?
    private var petNeedWiggleStartDate: Date?
    private var pendingCheckInSlotIndex: Int?
    private var isRiceVisible = false
    private var isRiceFeeding = false
    private var currentPetNeed: PetNeed?
    private var lastHungryToastNeedKey: String?
    private var demoPetNeedIndex = 0
    private var eatAnimationStartDate: Date?
    private var feedingOverlayIcon: String?
    private var feedingOverlayStartDate: Date?
    private var nextSleepAt = Date()
    private var sleepStartDate: Date?
    private var sleepEndDate: Date?
    private var wakingStartDate: Date?
    private var wakeJoltStartDate: Date?
    private var postWakeBlinkEndDate: Date?
    private var updateAvailableInfo: AppUpdateInfo?
    private var isCheckingForUpdates = false
    private var isUpdateBadgeDemoMode: Bool {
        ProcessInfo.processInfo.environment["KIKU_UPDATE_BADGE_DEMO"] == "1"
    }
    private var cancellables = Set<AnyCancellable>()

    override init() {
        let savedStyle = UserDefaults.standard.string(forKey: "FlowerIconStyle").flatMap(FlowerIconStyle.init(rawValue:))
        iconStyle = savedStyle ?? .fourPetal
        super.init()

        LaunchAtLoginController.apply(enabled: settings.launchAtLoginEnabled)
        petNeedBubbleWindow.onClick = { [weak self] in
            self?.feedRice()
        }
        configureStatusItem()
        configurePopover()
        configureActionPopover()
        configureReminderToast()
        bindSession()
        applyReminderSettings()
        session.start()
        scheduleNextSleep()
        startEyeLoop()
        refreshCachedUpdateInfo()
        configureUpdateDemoIfNeeded()
        refreshUpdateStatusIfNeeded()
        if isFeedingOverlayDemoMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                self?.runFeedingOverlayDemo()
            }
        } else if isToastDemoMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                if ProcessInfo.processInfo.environment["TOAST_DEMO_REMINDER_ONLY"] == "1" {
                    self?.runReminderToastDemo()
                } else {
                    self?.runToastDemoSequence()
                }
            }
        } else if !isSleepDemoMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
                self?.showStartupToastWhenReady()
            }
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = statusImage()
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageLeft
        button.action = #selector(handleStatusItemClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "提肛提醒"
    }

    private func configureOverlayTestStatusItemIfNeeded() {
        guard ProcessInfo.processInfo.environment["PET_NEED_OVERLAY_TEST_ICON"] == "1" else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: 24)
        overlayTestStatusItem = item
        guard let button = item.button else { return }
        button.image = statusImage()
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.toolTip = "浮层透明度测试图标"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 300, height: 232)
        let controller = NSHostingController(
            rootView: ExercisePopoverView(
                    session: session,
                    petStatusStore: petStatusStore,
                    noticeStore: popoverNoticeStore,
                    iconStyle: { [weak self] in self?.iconStyle ?? .fourPetal },
                    petStatus: { [weak self] in
                        self?.petStatusSnapshot() ?? PetStatusSnapshot(
                            fullness: 0,
                            hydration: 0,
                            energy: 0,
                            toilet: 0,
                            exercise: 0,
                            hydrationHint: "饮水0/2000ml",
                            toiletHint: "如厕还--分钟",
                            activityHint: "活动还--分钟",
                            hydrationDetail: "0/2000ml",
                            exerciseDetail: "0/\(DailyCheckInStore.slotCount(for: self?.settings.reminderScheduleMode ?? .weekdays, reminderInterval: self?.settings.kegelReminderInterval ?? .fortyFive))",
                            level: 1,
                            experience: 0,
                            moodText: "需要照顾一下"
                        )
                    },
                    startNow: { [weak self] in self?.beginExerciseFromUser() },
                    snooze: { [weak self] in self?.snoozeFromPopover() },
                    feedPet: { [weak self] in self?.feedPetFromPopover() },
                    drinkPet: { [weak self] in self?.drinkPetFromPopover() },
                    restPet: { [weak self] in self?.restPetFromPopover() },
                    toiletPet: { [weak self] in self?.toiletPetFromPopover() }
                )
        )
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        popover.contentViewController = controller
    }

    private func configureActionPopover() {
        actionPopover.behavior = .transient
        actionPopover.delegate = self
    }

    private func configureReminderToast() {
        reminderToast.onClose = { [weak self] in
            guard let self else { return }
            self.toastDismissTimer?.invalidate()
            self.toastDismissTimer = nil
            self.activeToast = nil
            guard !self.suppressToastContinueOnClose else { return }
            self.showNextPendingToastIfPossible()
        }
    }

    private func bindSession() {
        session.onReminder = { [weak self] in
            self?.showReminderToast()
        }
        session.onTick = { [weak self] in
            self?.refreshStatusText()
        }
        session.onFinishExercise = { [weak self] in
            self?.stopIconAnimation()
            self?.hideReminderToast()
            self?.clearPendingToasts()
            self?.nextPetNeedToastAllowedAt = Date().addingTimeInterval(45)
            self?.nextAmbientToastAllowedAt = Date().addingTimeInterval(90)
            self?.lastHungryToastNeedKey = nil
            self?.updateRiceVisibilityForHover()
        }

        session.$mode
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                switch mode {
                case .reminding:
                    self?.wakeFromSleep()
                    self?.startReminderWiggle()
                case .preparing:
                    self?.wakeFromSleep()
                    self?.reminderStartDate = nil
                    self?.suppressPetNeedDuringExercise()
                    self?.stopIconAnimation()
                case .exercising:
                    self?.wakeFromSleep()
                    self?.reminderStartDate = nil
                    self?.suppressPetNeedDuringExercise()
                    self?.startExerciseIconPulse()
                case .completing:
                    self?.reminderStartDate = nil
                    self?.suppressPetNeedDuringExercise()
                    self?.stopIconAnimation()
                case .idle:
                    self?.reminderStartDate = nil
                    self?.stopIconAnimation()
                }
                self?.refreshStatusText()
            }
            .store(in: &cancellables)
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp {
            wakeFromSleep()
            pauseVisibleToastForPopover()
            showContextMenu()
            showNextPendingToastIfPossible()
            return
        }

        wakeFromSleep()
        togglePopover()
    }

    private func feedRice() {
        if let currentPetNeed {
            feedPetNeed(currentPetNeed)
            return
        }
        feedPetNeed(PetNeed(key: "fallback.food", icon: "🍚", title: "饿了...", kind: .food))
    }

    private func feedPetNeed(_ need: PetNeed) {
        guard !isRiceFeeding else { return }
        guard let rect = statusItemScreenRect() else {
            isRiceVisible = false
            refreshStatusText()
            completePetNeedWithoutFlight(need)
            return
        }

        currentPetNeed = need
        isRiceFeeding = true
        nextAmbientToastAllowedAt = Date().addingTimeInterval(ambientAfterPetNeedDelay)
        wakeFromSleep()
        petNeedWiggleStartDate = nil
        isRiceVisible = false
        hidePetNeedBubble()
        refreshStatusText()
        _ = rect
        playInPlaceFeeding(icon: need.icon) { [weak self] in
            self?.finishPetNeedFlight()
        }
    }

    private func completePetNeedWithoutFlight(_ need: PetNeed) {
        currentPetNeed = need
        finishPetNeedFlight()
    }

    private func finishPetNeedFlight() {
        markCurrentPetNeedHandled()
        triggerEatAnimation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) { [weak self] in
            self?.isRiceFeeding = false
            self?.isRiceVisible = false
            self?.currentPetNeed = nil
            self?.nextPetNeedToastAllowedAt = Date().addingTimeInterval(self?.petNeedAfterAmbientDelay ?? 5 * 60)
            self?.nextAmbientToastAllowedAt = Date().addingTimeInterval(self?.ambientAfterPetNeedDelay ?? 5 * 60)
            self?.lastHungryToastNeedKey = nil
            self?.refreshStatusText()
            if self?.isFeedingOverlayDemoMode == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.runFeedingOverlayDemo()
                }
            }
        }
    }

    private func beginExerciseFromUser() {
        clearPendingToasts()
        hideReminderToast()
        suppressPetNeedDuringExercise()
        stopIconAnimation()
        if !isAnyDemoMode,
           checkInStore.markCompletion(
            preferredSlotIndex: pendingCheckInSlotIndex,
            scheduleMode: settings.reminderScheduleMode,
            reminderInterval: settings.kegelReminderInterval
           ) {
            petStatusStore.recordExercise()
        }
        pendingCheckInSlotIndex = nil
        session.startExercise()
        refreshStatusText()
    }

    private func petStatusSnapshot() -> PetStatusSnapshot {
        let summary = checkInStore.summary(
            scheduleMode: settings.reminderScheduleMode,
            reminderInterval: settings.kegelReminderInterval
        )
        return petStatusStore.snapshot(
            todayExerciseCount: summary.todayCount,
            exerciseSlotCount: summary.totalCount
        )
    }

    private func feedPetFromPopover() -> String? {
        return performPetCare(icon: "🍚", kind: .food, recordImmediately: true)
    }

    private func drinkPetFromPopover() -> String? {
        return performPetCare(icon: "🥤", kind: .drink, recordImmediately: true)
    }

    private func restPetFromPopover() -> String? {
        guard !session.isExerciseFlowActive else { return "运动中先专心提肛" }
        wakeFromSleep()
        let result = petStatusStore.recordRest()
        refreshStatusText()
        return result.didChange ? nil : result.message
    }

    private func toiletPetFromPopover() -> String? {
        guard !session.isExerciseFlowActive else { return "运动中先专心提肛" }
        wakeFromSleep()
        let result = petStatusStore.recordToilet()
        refreshStatusText()
        return result.didChange ? nil : result.message
    }

    private func performPetCare(icon: String, kind: PetCareKind, recordImmediately: Bool = false) -> String? {
        guard !isRiceFeeding else {
            if recordImmediately, kind == .food {
                _ = recordPetCare(kind: kind)
                refreshStatusText()
            }
            return nil
        }
        guard !session.isExerciseFlowActive else { return "运动中先专心提肛" }
        if recordImmediately {
            let result = recordPetCare(kind: kind)
            guard result.didChange else {
                refreshStatusText()
                return result.message
            }
        }

        guard statusItemScreenRect() != nil else {
            if !recordImmediately {
                _ = recordPetCare(kind: kind)
            }
            triggerEatAnimation()
            refreshStatusText()
            return nil
        }

        wakeFromSleep()
        isRiceFeeding = true
        isRiceVisible = false
        petNeedWiggleStartDate = nil
        hidePetNeedBubble()
        refreshStatusText()

        playInPlaceFeeding(icon: icon) { [weak self] in
            self?.finishPetCare(kind: kind, alreadyRecorded: recordImmediately)
        }
        return nil
    }

    private func playInPlaceFeeding(icon: String, completion: @escaping () -> Void) {
        feedingOverlayIcon = icon
        feedingOverlayStartDate = Date()
        refreshStatusText()

        DispatchQueue.main.asyncAfter(deadline: .now() + feedingOverlayDuration) { [weak self] in
            self?.feedingOverlayIcon = nil
            self?.feedingOverlayStartDate = nil
            self?.refreshStatusText()
            completion()
        }
    }

    private func finishPetCare(kind: PetCareKind, alreadyRecorded: Bool = false) {
        if let currentPetNeed, currentPetNeed.kind == kind {
            markCurrentPetNeedHandled(recordCare: !alreadyRecorded)
        } else if !alreadyRecorded {
            _ = recordPetCare(kind: kind)
        }

        triggerEatAnimation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) { [weak self] in
            self?.isRiceFeeding = false
            self?.isRiceVisible = false
            if self?.currentPetNeed?.kind == kind {
                self?.currentPetNeed = nil
            }
            self?.nextPetNeedToastAllowedAt = Date().addingTimeInterval(self?.petNeedAfterAmbientDelay ?? 5 * 60)
            self?.nextAmbientToastAllowedAt = Date().addingTimeInterval(self?.ambientAfterPetNeedDelay ?? 5 * 60)
            self?.lastHungryToastNeedKey = nil
            self?.refreshStatusText()
        }
    }

    private func recordPetCare(kind: PetCareKind) -> PetCareRecordResult {
        switch kind {
        case .food:
            return petStatusStore.recordFeed()
        case .drink:
            return petStatusStore.recordDrink()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.close()
        } else {
            actionPopover.close()
            pauseVisibleToastForPopover()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: popoverAnchorRect(in: button), of: button, preferredEdge: .minY)
            applyNativePopoverChrome(to: popover)
        }
    }

    private func popoverAnchorRect(in button: NSStatusBarButton) -> CGRect {
        guard !session.shortStatusText.isEmpty else {
            return button.bounds
        }

        let iconWidth = min(compactStatusItemLength, button.bounds.width)
        return CGRect(
            x: button.bounds.minX,
            y: button.bounds.minY,
            width: iconWidth,
            height: button.bounds.height
        )
    }

    private func showContextMenu() {
        refreshUpdateStatusIfNeeded()

        let menu = NSMenu()

        addCheckInItems(to: menu)
        menu.addItem(.separator())

        let start = NSMenuItem(title: "现在开始一次", action: #selector(startNowFromMenu), keyEquivalent: "")
        start.target = self
        menu.addItem(start)

        let snooze = NSMenuItem(title: "稍后 10 分钟提醒", action: #selector(snoozeFromMenu), keyEquivalent: "")
        snooze.target = self
        menu.addItem(snooze)

        let disableToday = NSMenuItem(title: "今天不再提醒", action: #selector(toggleRemindersForTodayFromMenu), keyEquivalent: "")
        disableToday.target = self
        disableToday.state = settings.areRemindersDisabledToday ? .on : .off
        menu.addItem(disableToday)

        let settingsItem = NSMenuItem(title: "设置", action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu()
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        menu.addItem(rewardMenuItem())

        menu.addItem(versionMenuItem())

        let restart = NSMenuItem(title: "重启插件", action: #selector(restartPlugin), keyEquivalent: "")
        restart.target = self
        menu.addItem(restart)

        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func rewardMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "请作者喝瑞 ☕️", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let qrItem = NSMenuItem()
        qrItem.view = rewardQRCodeView()
        submenu.addItem(qrItem)

        item.submenu = submenu
        return item
    }

    private func settingsMenu() -> NSMenu {
        let menu = NSMenu()

        let launchAtLogin = NSMenuItem(
            title: "开机启动",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLogin.target = self
        launchAtLogin.state = settings.launchAtLoginEnabled ? .on : .off
        menu.addItem(launchAtLogin)

        let popupReminders = NSMenuItem(
            title: "弹窗提醒",
            action: #selector(togglePopupReminders(_:)),
            keyEquivalent: ""
        )
        popupReminders.target = self
        popupReminders.state = settings.popupRemindersEnabled ? .on : .off
        menu.addItem(popupReminders)

        let easterEggReminders = NSMenuItem(
            title: "彩蛋提醒",
            action: #selector(toggleEasterEggReminders(_:)),
            keyEquivalent: ""
        )
        easterEggReminders.target = self
        easterEggReminders.state = settings.easterEggRemindersEnabled ? .on : .off
        menu.addItem(easterEggReminders)

        let intervalItem = NSMenuItem(title: "提肛提醒间隔", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for interval in KegelReminderInterval.allCases {
            let item = NSMenuItem(title: interval.title, action: #selector(selectKegelReminderInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interval.rawValue
            item.state = interval == settings.kegelReminderInterval ? .on : .off
            intervalMenu.addItem(item)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        let scheduleItem = NSMenuItem(title: "提醒时段", action: nil, keyEquivalent: "")
        let scheduleMenu = NSMenu()
        for mode in ReminderScheduleMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectReminderScheduleMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == settings.reminderScheduleMode ? .on : .off
            scheduleMenu.addItem(item)
        }
        scheduleItem.submenu = scheduleMenu
        menu.addItem(scheduleItem)

        return menu
    }

    private func versionMenuItem() -> NSMenuItem {
        if let updateAvailableInfo {
            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            item.view = VersionMenuItemView(
                version: appVersion,
                updateVersion: updateAvailableInfo.version,
                action: { [weak self] in
                    self?.checkForUpdatesFromMenu()
                }
            )
            return item
        }

        let title = isCheckingForUpdates ? "版本 \(appVersion)（检查中...）" : "版本 \(appVersion)"
        let item = NSMenuItem(
            title: title,
            action: #selector(checkForUpdatesFromMenu),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = !isCheckingForUpdates
        return item
    }

    private func rewardQRCodeView() -> NSView {
        let container = NSView(frame: CGRect(x: 0, y: 0, width: 260, height: 312))

        let title = NSTextField(labelWithString: "微信扫码赞赏")
        title.alignment = .center
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .labelColor
        title.frame = CGRect(x: 0, y: 280, width: 260, height: 20)
        container.addSubview(title)

        let imageView = NSImageView(frame: CGRect(x: 20, y: 48, width: 220, height: 220))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        imageView.image = Bundle.main.url(forResource: "WeChatReward", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
        container.addSubview(imageView)

        let contactIcon = NSImageView(frame: CGRect(x: 34, y: 17, width: 16, height: 16))
        contactIcon.image = Bundle.main.url(forResource: "WeChatIcon", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
        contactIcon.imageScaling = .scaleProportionallyUpOrDown
        container.addSubview(contactIcon)

        let contact = NSTextField(labelWithString: "交流学习  wechat:saierda997")
        contact.font = .systemFont(ofSize: 12, weight: .medium)
        contact.textColor = .secondaryLabelColor
        contact.frame = CGRect(x: 56, y: 14, width: 180, height: 20)
        container.addSubview(contact)

        return container
    }

    @objc private func startNowFromMenu() {
        beginExerciseFromUser()
        showPopoverAfterMenuActionSettles()
    }

    private func showPopoverAfterMenuActionSettles() {
        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self, !self.popover.isShown else { return }
                self.refreshStatusText()
                self.togglePopover()
            }
        }
    }

    @objc private func snoozeFromMenu() {
        hideReminderToast()
        nextPetNeedToastAllowedAt = Date().addingTimeInterval(45)
        nextAmbientToastAllowedAt = Date().addingTimeInterval(90)
        session.snooze(minutes: 10)
    }

    @objc private func toggleRemindersForTodayFromMenu() {
        if settings.areRemindersDisabledToday {
            settings.enableRemindersForToday()
            applyReminderSettings()
            wakeFromSleep()
            refreshStatusText()
            return
        }

        settings.disableRemindersForToday()
        clearPendingToasts()
        hideReminderToast()
        hidePetNeedBubble()
        currentPetNeed = nil
        isRiceVisible = false
        petNeedWiggleStartDate = nil
        lastHungryToastNeedKey = nil
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(24 * 60 * 60)
        let nextActiveStart = settings.reminderScheduleMode.nextActiveStart(
            after: Calendar.current.startOfDay(for: tomorrow).addingTimeInterval(-1)
        )
        session.pauseReminders(until: nextActiveStart)
        refreshStatusText()
        enterTodayPauseSleepIfPossible()
    }

    private func snoozeFromPopover() {
        hideReminderToast()
        nextPetNeedToastAllowedAt = Date().addingTimeInterval(45)
        nextAmbientToastAllowedAt = Date().addingTimeInterval(90)
        session.snooze(minutes: 10)
        popover.close()
    }

    @objc private func toggleLaunchAtLogin(_ item: NSMenuItem) {
        settings.launchAtLoginEnabled.toggle()
        LaunchAtLoginController.apply(enabled: settings.launchAtLoginEnabled)
        item.state = settings.launchAtLoginEnabled ? .on : .off
    }

    @objc private func togglePopupReminders(_ item: NSMenuItem) {
        settings.popupRemindersEnabled.toggle()
        item.state = settings.popupRemindersEnabled ? .on : .off

        if !settings.popupRemindersEnabled {
            clearPendingToasts()
            hideReminderToast()
            hidePetNeedBubble()
            petNeedWiggleStartDate = nil
            lastHungryToastNeedKey = nil
            refreshStatusText()
        }
    }

    @objc private func toggleEasterEggReminders(_ item: NSMenuItem) {
        settings.easterEggRemindersEnabled.toggle()
        item.state = settings.easterEggRemindersEnabled ? .on : .off

        if !settings.easterEggRemindersEnabled {
            clearPendingToasts()
            hidePetNeedBubble()
            currentPetNeed = nil
            isRiceVisible = false
            petNeedWiggleStartDate = nil
            lastHungryToastNeedKey = nil
            feedingOverlayIcon = nil
            feedingOverlayStartDate = nil
            refreshStatusText()
        }
    }

    @objc private func selectReminderScheduleMode(_ item: NSMenuItem) {
        guard
            let rawValue = item.representedObject as? String,
            let mode = ReminderScheduleMode(rawValue: rawValue)
        else { return }

        settings.reminderScheduleMode = mode
        applyReminderSettings()
        refreshStatusText()
    }

    @objc private func selectKegelReminderInterval(_ item: NSMenuItem) {
        guard
            let rawValue = item.representedObject as? Int,
            let interval = KegelReminderInterval(rawValue: rawValue)
        else { return }

        settings.kegelReminderInterval = interval
        applyReminderSettings()
        refreshStatusText()
    }

    private func applyReminderSettings() {
        session.applyReminderInterval(settings.kegelReminderInterval)
        applyReminderScheduleMode(settings.reminderScheduleMode)
    }

    private func applyReminderScheduleMode(_ mode: ReminderScheduleMode) {
        session.applyScheduleMode(mode)
        petStatusStore.applyScheduleMode(mode)
        if !mode.isActive(at: Date()) {
            clearPendingToasts()
            hideReminderToast()
            hidePetNeedBubble()
            petNeedWiggleStartDate = nil
            lastHungryToastNeedKey = nil
        }
    }

    @objc private func checkForUpdatesFromMenu() {
        refreshUpdateStatus(force: true, notify: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func restartPlugin() {
        let appPath = Bundle.main.bundleURL.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.4; open \"\(appPath)\""]
        try? process.run()
        NSApp.terminate(nil)
    }

    private func showReminderToast() {
        guard !settings.areRemindersDisabledToday else {
            hideReminderToast()
            return
        }
        pendingCheckInSlotIndex = checkInStore.nearestSlotIndex(
            scheduleMode: settings.reminderScheduleMode,
            reminderInterval: settings.kegelReminderInterval
        )
        guard settings.popupRemindersEnabled,
              settings.easterEggRemindersEnabled,
              !settings.areRemindersDisabledToday else {
            return
        }
        let reminderMessage = currentReminderMessage()
        popover.close()
        startReminderWiggle()
        showReminderPopoverWhenReady(title: reminderMessage.title, subtitle: reminderMessage.subtitle)
    }

    private func showReminderPopoverWhenReady(title: String, subtitle: String, remainingAttempts: Int = 8) {
        guard statusItem.button != nil else {
            guard remainingAttempts > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.showReminderPopoverWhenReady(
                    title: title,
                    subtitle: subtitle,
                    remainingAttempts: remainingAttempts - 1
                )
            }
            return
        }

        if isExerciseReminderTitle(title) {
            startReminderWiggle()
        }

        showToast(
            title: title,
            subtitle: "",
            systemImageName: nil,
            duration: 0,
            action: nil,
            primaryButtonTitle: "立即开始",
            primaryAction: { [weak self] in
                self?.beginExerciseFromUser()
            },
            secondaryButtonTitle: "稍后",
            secondaryAction: { [weak self] in
                self?.snoozeFromReminderToast()
            }
        )
    }

    private func currentReminderMessage(at date: Date = Date()) -> (title: String, subtitle: String) {
        let summary = checkInStore.summary(
            for: date,
            scheduleMode: settings.reminderScheduleMode,
            reminderInterval: settings.kegelReminderInterval
        )
        if shouldShowSurpassYesterdayPrompt(summary: summary, at: date) {
            return ("再运动一次就超过昨天的记录啦", "")
        }
        return ("时间到", "")
    }

    private func shouldShowSurpassYesterdayPrompt(summary: DailyCheckInSummary, at date: Date) -> Bool {
        guard summary.yesterdayCount >= 4 else {
            return false
        }
        guard summary.todayCount == summary.yesterdayCount else {
            return false
        }
        guard summary.todayCount < summary.totalCount else {
            return false
        }

        let hour = Calendar.current.component(.hour, from: date)
        return hour < 20
    }

    private func showStartupToast() {
        guard settings.popupRemindersEnabled,
              settings.easterEggRemindersEnabled,
              !settings.areRemindersDisabledToday else {
            return
        }
        guard !reminderToast.isShown, session.mode != .reminding else {
            return
        }

        showToast(
            title: "提肛小助手已启动",
            subtitle: "",
            systemImageName: nil,
            duration: 8,
            action: nil,
            primaryButtonTitle: "立即开始",
            primaryAction: { [weak self] in
                self?.beginExerciseFromUser()
            },
            secondaryButtonTitle: "稍后",
            secondaryAction: { [weak self] in
                self?.hideReminderToast()
            }
        )
    }

    private func showStartupToastWhenReady(remainingAttempts: Int = 8) {
        guard statusItem.button != nil else {
            guard remainingAttempts > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.showStartupToastWhenReady(remainingAttempts: remainingAttempts - 1)
            }
            return
        }

        showStartupToast()
    }

    private func runToastDemoSequence() {
        let steps: [(delay: TimeInterval, action: () -> Void)] = [
            (0.0, { [weak self] in
                self?.showToast(
                    title: "提肛小助手已启动",
                    subtitle: "",
                    systemImageName: nil,
                    duration: 3.0,
                    action: nil,
                    primaryButtonTitle: "立即开始",
                    primaryAction: { [weak self] in self?.beginExerciseFromUser() },
                    secondaryButtonTitle: "稍后",
                    secondaryAction: { [weak self] in self?.hideReminderToast() }
                )
            }),
            (3.8, { [weak self] in
                self?.reminderStartDate = Date()
                self?.showToast(
                    title: "时间到",
                    subtitle: "",
                    systemImageName: nil,
                    duration: 3.2,
                    action: nil,
                    primaryButtonTitle: "立即开始",
                    primaryAction: { [weak self] in self?.beginExerciseFromUser() },
                    secondaryButtonTitle: "稍后",
                    secondaryAction: { [weak self] in self?.snoozeFromReminderToast() }
                )
            }),
            (7.6, { [weak self] in
                self?.showToast(
                    title: "再运动一次就超过昨天的记录啦",
                    subtitle: "",
                    systemImageName: nil,
                    duration: 3.2,
                    action: nil,
                    primaryButtonTitle: "立即开始",
                    primaryAction: { [weak self] in self?.beginExerciseFromUser() },
                    secondaryButtonTitle: "稍后",
                    secondaryAction: { [weak self] in self?.snoozeFromReminderToast() }
                )
            }),
            (11.4, { [weak self] in
                guard let self else { return }
                let need = PetNeed(
                    key: "demo.toast.food.\(ProcessInfo.processInfo.processIdentifier)",
                    icon: "🍚",
                    title: "饿了...",
                    kind: .food
                )
                self.currentPetNeed = need
                self.petNeedWiggleStartDate = Date()
                self.showHungryToastIfNeeded(for: need)
            }),
            (14.8, { [weak self] in
                guard let self else { return }
                let need = PetNeed(
                    key: "demo.toast.drink.\(ProcessInfo.processInfo.processIdentifier)",
                    icon: "☕️",
                    title: "渴了...",
                    kind: .drink
                )
                self.currentPetNeed = need
                self.petNeedWiggleStartDate = Date()
                self.showHungryToastIfNeeded(for: need)
            }),
            (18.2, { [weak self] in
                self?.showToast(
                    title: "🐟",
                    subtitle: "",
                    systemImageName: nil,
                    duration: 3.0,
                    action: nil,
                    primaryButtonTitle: nil,
                    primaryAction: nil,
                    secondaryButtonTitle: nil,
                    secondaryAction: nil
                )
            }),
            (21.6, { [weak self] in
                self?.showToast(
                    title: "💩",
                    subtitle: "",
                    systemImageName: nil,
                    duration: 3.0,
                    action: nil,
                    primaryButtonTitle: nil,
                    primaryAction: nil,
                    secondaryButtonTitle: nil,
                    secondaryAction: nil
                )
            }),
            (25.0, { [weak self] in
                self?.showToast(
                    title: "🏃",
                    subtitle: "",
                    systemImageName: nil,
                    duration: 3.0,
                    action: nil,
                    primaryButtonTitle: nil,
                    primaryAction: nil,
                    secondaryButtonTitle: nil,
                    secondaryAction: nil
                )
            }),
            (28.4, { [weak self] in
                self?.reminderStartDate = nil
                self?.petNeedWiggleStartDate = nil
                self?.hideReminderToast()
                self?.refreshStatusText()
            })
        ]

        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                step.action()
            }
        }

        if isToastDemoLoopMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.6) { [weak self] in
                self?.runToastDemoSequence()
            }
        }
    }

    private func runReminderToastDemo() {
        reminderStartDate = Date()
        pendingCheckInSlotIndex = checkInStore.nearestSlotIndex(
            scheduleMode: settings.reminderScheduleMode,
            reminderInterval: settings.kegelReminderInterval
        )
        showToast(
            title: "时间到",
            subtitle: "",
            systemImageName: nil,
            duration: 0,
            action: nil,
            primaryButtonTitle: "立即开始",
            primaryAction: { [weak self] in self?.beginExerciseFromUser() },
            secondaryButtonTitle: "稍后",
            secondaryAction: { [weak self] in self?.snoozeFromReminderToast() }
        )
    }

    private func runFeedingOverlayDemo() {
        let need = PetNeed(
            key: "demo.overlay.food.\(ProcessInfo.processInfo.processIdentifier).\(Date().timeIntervalSince1970)",
            icon: "🍚",
            title: "饿了...",
            kind: .food
        )
        currentPetNeed = need
        petNeedWiggleStartDate = Date()
        showHungryToastIfNeeded(for: need)
    }

    private func showToast(
        title: String,
        subtitle: String,
        systemImageName: String?,
        layout: ToastLayout = .compact,
        duration: TimeInterval,
        action: (() -> Void)?,
        primaryButtonTitle: String?,
        primaryAction: (() -> Void)?,
        secondaryButtonTitle: String?,
        secondaryAction: (() -> Void)?,
        timeoutAction: (() -> Void)? = nil
    ) {
        guard settings.popupRemindersEnabled else {
            return
        }

        let toast = PendingToast(
            title: title,
            subtitle: subtitle,
            systemImageName: systemImageName,
            layout: layout,
            duration: duration,
            action: action,
            primaryButtonTitle: primaryButtonTitle,
            primaryAction: primaryAction,
            secondaryButtonTitle: secondaryButtonTitle,
            secondaryAction: secondaryAction,
            timeoutAction: timeoutAction
        )

        guard !popover.isShown, !actionPopover.isShown, !reminderToast.isShown, toastSequenceTimer == nil else {
            enqueueToast(toast)
            return
        }

        presentToast(toast)
    }

    private func presentPopoverToast(_ toast: PendingToast) {
        guard let button = statusItem.button else { return }
        activeToast = toast
        toastDismissTimer?.invalidate()
        toastDismissTimer = nil
        reminderToast.hide()
        popover.close()

        let controller = NSHostingController(
            rootView: ReminderToastView(
                title: toast.title,
                subtitle: toast.subtitle,
                systemImageName: toast.systemImageName,
                layout: toast.layout,
                action: { [weak self] in
                    self?.handlePopoverToastAction(
                        toast.action,
                        keepPopoverOpen: self?.isExerciseReminderToast(toast) == true
                    )
                },
                primaryButtonTitle: toast.primaryButtonTitle,
                primaryAction: { [weak self] in
                    self?.handlePopoverToastAction(
                        toast.primaryAction,
                        keepPopoverOpen: self?.isExerciseReminderToast(toast) == true
                    )
                },
                secondaryButtonTitle: toast.secondaryButtonTitle,
                secondaryAction: { [weak self] in
                    self?.handlePopoverToastAction(toast.secondaryAction, keepPopoverOpen: false)
                },
                showsArrow: false
            )
        )
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        actionPopover.contentSize = actionPopoverSize(for: toast)
        actionPopover.contentViewController = controller

        NSApp.activate(ignoringOtherApps: true)
        if !actionPopover.isShown {
            actionPopover.show(relativeTo: popoverAnchorRect(in: button), of: button, preferredEdge: .minY)
            applyNativePopoverChrome(to: actionPopover)
        }
    }

    private func actionPopoverSize(for toast: PendingToast) -> NSSize {
        if toast.layout == .petAction {
            return NSSize(width: 96, height: 101)
        }

        if toast.primaryButtonTitle != nil {
            let titleWidth = CGFloat(toast.title.count) * 13 + 34
            return NSSize(width: min(220, max(167, titleWidth)), height: 77)
        }

        let titleWidth = CGFloat(toast.title.count) * 11 + 25
        let subtitleWidth = toast.subtitle.isEmpty ? 0 : CGFloat(toast.subtitle.count) * 8 + 27
        let bodyWidth = min(155, max(76, max(titleWidth, subtitleWidth) * 1.16))
        let bodyHeight: CGFloat = toast.subtitle.isEmpty ? 34 : 44
        return NSSize(width: bodyWidth, height: bodyHeight + 6)
    }

    private func handlePopoverToastAction(_ action: (() -> Void)?, keepPopoverOpen: Bool) {
        activeToast = nil
        popoverNoticeStore.notice = nil
        action?()
        if !keepPopoverOpen {
            actionPopover.close()
        }
        showNextPendingToastIfPossible()
    }

    private func enqueueToast(_ toast: PendingToast) {
        guard toastNeedsAction(toast) else {
            return
        }

        if toastNeedsAction(toast) {
            let insertIndex = pendingToasts.firstIndex { !toastNeedsAction($0) } ?? pendingToasts.endIndex
            pendingToasts.insert(toast, at: insertIndex)
        } else {
            pendingToasts.append(toast)
        }
    }

    private func toastNeedsAction(_ toast: PendingToast) -> Bool {
        toast.duration <= 0
            || toast.action != nil
            || toast.primaryButtonTitle != nil
            || toast.secondaryButtonTitle != nil
    }

    private func clearPendingToasts() {
        pendingToasts.removeAll()
        pendingToastPresentation?.cancel()
        pendingToastPresentation = nil
        toastSequenceTimer?.invalidate()
        toastSequenceTimer = nil
    }

    private func presentToast(_ toast: PendingToast) {
        toastSequenceTimer?.invalidate()
        toastSequenceTimer = nil
        toastDismissTimer?.invalidate()
        activeToast = toast

        pendingToastPresentation?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.presentToastAfterLayoutSettles(toast)
        }
        pendingToastPresentation = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func presentToastAfterLayoutSettles(_ toast: PendingToast) {
        guard activeToast?.title == toast.title else { return }
        guard let statusRect = statusItemScreenRect() else { return }
        pendingToastPresentation = nil
        reminderToast.show(
            title: toast.title,
            subtitle: toast.subtitle,
            systemImageName: toast.systemImageName,
            layout: toast.layout,
            action: toast.action,
            primaryButtonTitle: toast.primaryButtonTitle,
            primaryAction: toast.primaryAction,
            secondaryButtonTitle: toast.secondaryButtonTitle,
            secondaryAction: toast.secondaryAction,
            near: statusRect
        )

        if toast.duration > 0 {
            toastDismissTimer = Timer.scheduledTimer(withTimeInterval: toast.duration, repeats: false) { [weak self] _ in
                toast.timeoutAction?()
                self?.hideReminderToast()
            }
        } else {
            toastDismissTimer = nil
        }
    }

    private func showNextPendingToastIfPossible() {
        guard !popover.isShown, !actionPopover.isShown, !reminderToast.isShown, !pendingToasts.isEmpty, toastSequenceTimer == nil else {
            return
        }

        toastSequenceTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.toastSequenceTimer = nil
            guard !self.popover.isShown, !self.actionPopover.isShown, !self.reminderToast.isShown, !self.pendingToasts.isEmpty else {
                return
            }

            let toast = self.pendingToasts.removeFirst()
            self.presentToast(toast)
        }
    }

    private func pauseVisibleToastForPopover() {
        guard reminderToast.isShown else { return }
        if let activeToast {
            enqueueToast(activeToast)
        }
        activeToast = nil
        toastDismissTimer?.invalidate()
        toastDismissTimer = nil
        suppressToastContinueOnClose = true
        reminderToast.hide()
        suppressToastContinueOnClose = false
    }

    private func applyNativePopoverChrome(to popover: NSPopover) {
        guard let window = popover.contentViewController?.view.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.8"
    }

    private func refreshCachedUpdateInfo() {
        guard
            let version = settings.cachedUpdateVersion,
            let urlString = settings.cachedUpdateURL,
            let url = URL(string: urlString),
            GitHubUpdateChecker.isVersion(version, newerThan: appVersion)
        else {
            updateAvailableInfo = nil
            return
        }

        updateAvailableInfo = AppUpdateInfo(
            version: version,
            url: url,
            title: nil,
            notes: nil
        )
    }

    private func configureUpdateDemoIfNeeded() {
        guard isUpdateBadgeDemoMode else {
            return
        }

        updateAvailableInfo = AppUpdateInfo(
            version: "0.2.8",
            url: URL(string: "https://github.com/saierda990-jpg/kegel-flower/releases")!,
            title: "v0.2.8",
            notes: nil
        )
    }

    private func refreshUpdateStatusIfNeeded() {
        guard !isUpdateBadgeDemoMode else { return }

        if let lastCheck = settings.lastUpdateCheckAt,
           Date().timeIntervalSince(lastCheck) < 30 * 60 {
            return
        }

        refreshUpdateStatus(force: false, notify: false)
    }

    private func refreshUpdateStatus(force: Bool, notify: Bool) {
        if isUpdateBadgeDemoMode {
            if notify, let updateAvailableInfo {
                showUpdateAvailableAlert(updateAvailableInfo)
            }
            return
        }

        guard !isCheckingForUpdates else { return }
        guard force || settings.popupRemindersEnabled || settings.lastUpdateCheckAt == nil else { return }

        isCheckingForUpdates = true
        updateChecker.check(currentVersion: appVersion) { [weak self] result in
            guard let self else { return }
            self.isCheckingForUpdates = false
            self.settings.lastUpdateCheckAt = Date()

            switch result {
            case .updateAvailable(let info):
                self.updateAvailableInfo = info
                self.settings.cachedUpdateVersion = info.version
                self.settings.cachedUpdateURL = info.url.absoluteString
                if notify {
                    self.showUpdateAvailableAlert(info)
                }
            case .upToDate:
                self.updateAvailableInfo = nil
                self.settings.cachedUpdateVersion = nil
                self.settings.cachedUpdateURL = nil
                if notify {
                    self.showNoUpdatesAlert()
                }
            case .failed(let message):
                if notify {
                    self.showUpdateCheckFailedAlert(message)
                }
            }
        }
    }

    private func showUpdateAvailableAlert(_ info: AppUpdateInfo) {
        let alert = NSAlert()
        alert.messageText = "发现新版本"
        alert.informativeText = "当前版本 \(appVersion)，最新版本 \(info.version)。"
        alert.addButton(withTitle: "前往下载")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(info.url)
        }
    }

    private func showNoUpdatesAlert() {
        let alert = NSAlert()
        alert.messageText = "已经是最新版本"
        alert.informativeText = "当前版本 \(appVersion) 已是最新。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showUpdateCheckFailedAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "暂时无法检查更新"
        alert.informativeText = "\(message)\n请稍后再试，或前往 GitHub 查看最新版本。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func hideReminderToast() {
        let shouldStopReminderWiggle = activeToast.map(isExerciseReminderToast) ?? false
        pendingToastPresentation?.cancel()
        pendingToastPresentation = nil
        toastDismissTimer?.invalidate()
        toastDismissTimer = nil
        activeToast = nil
        popoverNoticeStore.notice = nil
        if shouldStopReminderWiggle {
            reminderStartDate = nil
        }
        reminderToast.hide()
    }

    private func addCheckInItems(to menu: NSMenu) {
        let summary = checkInStore.summary(
            scheduleMode: settings.reminderScheduleMode,
            reminderInterval: settings.kegelReminderInterval
        )

        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.view = CheckInMenuHeaderView(summary: summary)
        menu.addItem(item)
    }

    private func snoozeFromReminderToast() {
        hideReminderToast()
        nextPetNeedToastAllowedAt = Date().addingTimeInterval(45)
        nextAmbientToastAllowedAt = Date().addingTimeInterval(90)
        session.snooze(minutes: 10)
    }

    private func startReminderWiggle() {
        reminderStartDate = Date()
        iconAnimationTimer?.invalidate()
        iconAnimationTimer = nil
    }

    private func startExerciseIconPulse() {
        iconAnimationTimer?.invalidate()
        pulseStartDate = Date()
        lastRenderedPhase = session.phase
        iconAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.renderExercisePulseIcon()
        }
    }

    private func stopIconAnimation() {
        iconAnimationTimer?.invalidate()
        iconAnimationTimer = nil
        statusItem.button?.image = statusImage()
    }

    private func refreshStatusText() {
        guard let button = statusItem.button else { return }
        let statusText = session.shortStatusText
        statusItem.length = statusText.isEmpty ? compactStatusItemLength : exerciseStatusItemLength
        button.attributedTitle = NSAttributedString(string: "")
        button.title = statusText
        button.imagePosition = statusText.isEmpty ? .imageOnly : .imageLeft
        if session.mode == .exercising {
            renderExercisePulseIcon()
        } else if iconAnimationTimer == nil {
            button.image = statusImage()
        }
        repositionReminderToastIfNeeded()
    }

    private func renderExercisePulseIcon() {
        guard session.mode == .exercising else { return }

        if session.phase != lastRenderedPhase {
            lastRenderedPhase = session.phase
            pulseStartDate = Date()
        }

        let elapsed = Date().timeIntervalSince(pulseStartDate)
        let animationDuration: TimeInterval = session.phase == .contract ? 1.0 : 0.45
        let progress = max(0, min(1, elapsed / animationDuration))
        let eased = session.phase == .contract
            ? 0.5 - cos(progress * .pi) / 2
            : 1 - pow(1 - progress, 3)
        let startScale: CGFloat = session.phase == .contract ? 1.0 : 0.54
        let endScale: CGFloat = session.phase == .contract ? 0.54 : 1.0
        let scale = startScale + (endScale - startScale) * CGFloat(eased)

        statusItem.button?.image = statusImage(scale: scale)
    }

    private func startEyeLoop() {
        scheduleNextBlink()
        eyeTimer?.invalidate()
        eyeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 18.0, repeats: true) { [weak self] _ in
            self?.advanceEyes()
        }
    }

    private func advanceEyes() {
        let now = Date()

        if now >= nextBlinkAt {
            triggerBlink()
            scheduleNextBlink()
        }

        updateSleepState(now: now)
        updateLookOffsetTowardMouse()
        updateIconTilt()
        updateRiceVisibilityForHover()
        showDailyAmbientToastsIfNeeded(at: now)

        if iconAnimationTimer == nil && session.mode != .exercising {
            statusItem.button?.image = statusImage()
        }
        repositionReminderToastIfNeeded()
    }

    private func repositionReminderToastIfNeeded() {
        guard reminderToast.isShown, let statusRect = statusItemScreenRect() else { return }
        reminderToast.reposition(near: statusRect)
    }

    private func updateRiceVisibilityForHover() {
        guard !isRiceFeeding else {
            return
        }

        guard settings.popupRemindersEnabled, !settings.areRemindersDisabledToday else {
            let shouldRefresh = isRiceVisible || petNeedBubbleWindow.isVisible || petNeedWiggleStartDate != nil
            isRiceVisible = false
            currentPetNeed = nil
            petNeedWiggleStartDate = nil
            lastHungryToastNeedKey = nil
            hidePetNeedBubble()
            if shouldRefresh {
                refreshStatusText()
            }
            return
        }

        if session.isExerciseFlowActive {
            suppressPetNeedDuringExercise()
            return
        }

        if sleepStartDate != nil || wakingStartDate != nil {
            return
        }

        guard Date() >= nextPetNeedToastAllowedAt else {
            petNeedWiggleStartDate = nil
            return
        }

        let need = activePetNeed()
        currentPetNeed = need
        if need != nil {
            guard !popover.isShown, !reminderToast.isShown else {
                petNeedWiggleStartDate = nil
                return
            }
            if petNeedWiggleStartDate == nil {
                petNeedWiggleStartDate = Date()
            }
            showHungryToastIfNeeded(for: need)
        } else {
            petNeedWiggleStartDate = nil
            lastHungryToastNeedKey = nil
        }

        if isRiceVisible || petNeedBubbleWindow.isVisible {
            isRiceVisible = false
            hidePetNeedBubble()
            refreshStatusText()
        }
    }

    private func suppressPetNeedDuringExercise() {
        let shouldRefresh = isRiceVisible || petNeedBubbleWindow.isVisible || petNeedWiggleStartDate != nil
        isRiceVisible = false
        currentPetNeed = nil
        petNeedWiggleStartDate = nil
        hidePetNeedBubble()
        if shouldRefresh {
            refreshStatusText()
        }
    }

    private func updatePetNeedBubble() {
        guard settings.popupRemindersEnabled, !settings.areRemindersDisabledToday else {
            hidePetNeedBubble()
            return
        }
        guard let currentPetNeed, let rect = statusItemScreenRect() else { return }
        petNeedBubbleWindow.show(icon: currentPetNeed.icon, near: rect)
    }

    private func hidePetNeedBubble() {
        petNeedBubbleWindow.hide()
    }

    private func activePetNeed(at date: Date = Date()) -> PetNeed? {
        guard settings.easterEggRemindersEnabled else {
            return nil
        }

        if ProcessInfo.processInfo.environment["PET_NEED_DEMO_SEQUENCE"] == "1" {
            let demoNeeds = [
                PetNeed(key: "demo.meal.\(ProcessInfo.processInfo.processIdentifier)", icon: "🍚", title: "饿了...", kind: .food),
                PetNeed(key: "demo.snack.\(ProcessInfo.processInfo.processIdentifier)", icon: "🍩", title: "饿了...", kind: .food),
                PetNeed(key: "demo.drink.\(ProcessInfo.processInfo.processIdentifier)", icon: "☕️", title: "渴了...", kind: .drink)
            ]
            guard demoPetNeedIndex < demoNeeds.count else { return nil }
            return demoNeeds[demoPetNeedIndex]
        }

        guard settings.reminderScheduleMode.isActive(at: date) else {
            return nil
        }

        let candidates = scheduledPetNeeds(for: date)
        return candidates.first { !fedPetNeedKeys().contains($0.key) }
    }

    private func scheduledPetNeeds(for date: Date) -> [PetNeed] {
        guard settings.reminderScheduleMode.isActiveDay(date) else {
            return []
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return []
        }

        var needs: [PetNeed] = []

        let mealTimes: [(id: String, hour: Int, minute: Int)] = [
            ("breakfast", 10, 0),
            ("lunch", 11, 30),
            ("dinner", 17, 30)
        ]

        for meal in mealTimes {
            var mealComponents = DateComponents()
            mealComponents.year = year
            mealComponents.month = month
            mealComponents.day = day
            mealComponents.hour = meal.hour
            mealComponents.minute = meal.minute
            guard let mealDate = calendar.date(from: mealComponents) else {
                continue
            }

            if date >= mealDate {
                needs.append(
                    PetNeed(
                        key: String(format: "%04d-%02d-%02d.meal.%@", year, month, day, meal.id),
                        icon: "🍚",
                        title: "饿了...",
                        kind: .food
                    )
                )
            }
        }

        for snack in snackTimes(year: year, month: month, day: day) {
            if date >= snack.date {
                needs.append(
                    PetNeed(
                        key: String(format: "%04d-%02d-%02d.snack.%d", year, month, day, snack.index),
                        icon: petIcon(from: ["🍬", "🍦", "🍩"], key: snack.index + day),
                        title: "饿了...",
                        kind: .food
                    )
                )
            }
        }

        for water in waterTimes(year: year, month: month, day: day) {
            if date >= water.date {
                needs.append(
                    PetNeed(
                        key: String(format: "%04d-%02d-%02d.drink.%d", year, month, day, water.index),
                        icon: petIcon(from: ["💧", "☕️", "🥤", "🍋"], key: water.index + day),
                        title: "渴了...",
                        kind: .drink
                    )
                )
            }
        }

        return needs
    }

    private func snackTimes(year: Int, month: Int, day: Int) -> [(index: Int, date: Date)] {
        let seed = abs(year * 10_000 + month * 100 + day)
        let firstMinute = 14 * 60 + 15 + seed % 70
        let secondMinute = 19 * 60 + 10 + (seed / 7) % 70
        return [firstMinute, secondMinute].enumerated().compactMap { index, minuteOfDay in
            dateOnDay(year: year, month: month, day: day, minuteOfDay: minuteOfDay).map { (index, $0) }
        }
    }

    private func waterTimes(year: Int, month: Int, day: Int) -> [(index: Int, date: Date)] {
        let slots = evenlySpacedMinutes(
            count: 10,
            startMinute: settings.reminderScheduleMode.startMinute,
            endMinute: settings.reminderScheduleMode.endMinute
        )
        return slots.enumerated().compactMap { index, minuteOfDay in
            dateOnDay(year: year, month: month, day: day, minuteOfDay: minuteOfDay).map { (index, $0) }
        }
    }

    private func evenlySpacedMinutes(count: Int, startMinute: Int, endMinute: Int) -> [Int] {
        guard count > 1 else { return [startMinute] }
        let lastMinute = max(startMinute, endMinute - 60)
        let span = max(0, lastMinute - startMinute)
        return (0..<count).map { index in
            startMinute + Int(round(Double(span) * Double(index) / Double(count - 1)))
        }
    }

    private func petIcon(from icons: [String], key: Int) -> String {
        guard !icons.isEmpty else { return "🍚" }
        return icons[abs(key) % icons.count]
    }

    private func dateOnDay(year: Int, month: Int, day: Int, minuteOfDay: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        return Calendar.current.date(from: components)
    }

    private func fedPetNeedKeys() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: fedPetNeedStorageKey) ?? [])
    }

    private func markCurrentPetNeedHandled(recordCare: Bool = true) {
        guard let need = currentPetNeed else { return }
        if recordCare {
            _ = recordPetCare(kind: need.kind)
        }
        if ProcessInfo.processInfo.environment["PET_NEED_DEMO_SEQUENCE"] == "1" {
            demoPetNeedIndex += 1
            return
        }

        var keys = fedPetNeedKeys()
        keys.insert(need.key)
        UserDefaults.standard.set(Array(keys).sorted(), forKey: fedPetNeedStorageKey)
    }

    private func showHungryToastIfNeeded(for need: PetNeed?) {
        guard settings.easterEggRemindersEnabled else {
            return
        }
        guard let need else {
            return
        }

        if lastHungryToastNeedKey == need.key {
            return
        }

        guard !popover.isShown else {
            return
        }

        lastHungryToastNeedKey = need.key
        nextAmbientToastAllowedAt = Date().addingTimeInterval(ambientAfterPetNeedDelay)
        showToast(
            title: need.icon,
            subtitle: "",
            systemImageName: nil,
            layout: .petAction,
            duration: 0,
            action: nil,
            primaryButtonTitle: need.kind == .drink ? "喝一杯" : "投喂",
            primaryAction: { [weak self, need] in self?.feedPetNeed(need) },
            secondaryButtonTitle: nil,
            secondaryAction: nil
        )
    }

    private func expirePetNeed(_ need: PetNeed) {
        if ProcessInfo.processInfo.environment["PET_NEED_DEMO_SEQUENCE"] == "1" {
            demoPetNeedIndex += 1
        } else {
            var keys = fedPetNeedKeys()
            keys.insert(need.key)
            UserDefaults.standard.set(Array(keys).sorted(), forKey: fedPetNeedStorageKey)
        }
        currentPetNeed = nil
        petNeedWiggleStartDate = nil
        isRiceVisible = false
        hidePetNeedBubble()
        refreshStatusText()
    }

    private func showDailyAmbientToastsIfNeeded(at date: Date) {
        guard settings.popupRemindersEnabled,
              settings.easterEggRemindersEnabled,
              !settings.areRemindersDisabledToday else {
            return
        }
        guard session.mode == .idle, !popover.isShown, !actionPopover.isShown, !reminderToast.isShown else {
            return
        }

        guard date >= nextAmbientToastAllowedAt else {
            return
        }

        guard settings.reminderScheduleMode.isActive(at: date) else { return }
        guard activePetNeed(at: date) == nil else { return }
        if showWalkToastIfNeeded(at: date) {
            return
        }

        if showHourlyAmbientToastIfNeeded(
            emojis: ["🐟"],
            storageKey: fishToastStorageKey,
            countPerHour: 2,
            hourStep: 1,
            seedOffset: 23,
            at: date
        ) {
            return
        }

        if showHourlyAmbientToastIfNeeded(
            emojis: ["🍬", "🍭", "🍫"],
            storageKey: candyToastStorageKey,
            countPerHour: 1,
            hourStep: 1,
            seedOffset: 31,
            at: date
        ) {
            return
        }

        _ = showHourlyAmbientToastIfNeeded(
            emojis: ["💩"],
            storageKey: toiletToastStorageKey,
            countPerHour: 1,
            hourStep: 2,
            seedOffset: 47,
            at: date
        )
    }

    private func showHourlyAmbientToastIfNeeded(
        emojis: [String],
        storageKey: String,
        countPerHour: Int,
        hourStep: Int,
        seedOffset: Int,
        at date: Date
    ) -> Bool {
        let minute = minuteOfDay(for: date)
        let workStart = settings.reminderScheduleMode.startMinute
        guard settings.reminderScheduleMode.isActive(at: date) else {
            return false
        }

        let day = dayKey(for: date)
        let hourIndex = (minute - workStart) / 60
        guard hourStep <= 1 || hourIndex % hourStep == 0 else {
            return false
        }

        let minuteInHour = minute % 60
        var shown = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let seed = abs((components.year ?? 0) * 10_000 + (components.month ?? 0) * 100 + (components.day ?? 0) + seedOffset + hourIndex * 37)

        for index in 0..<max(1, countPerHour) {
            let slotLength = 60 / max(1, countPerHour)
            let slotStart = index * slotLength
            let jitterRange = max(1, slotLength / 2)
            let scheduledMinute = min(57, slotStart + 8 + ((seed + index * 17) % jitterRange))
            guard minuteInHour >= scheduledMinute else {
                continue
            }

            let key = "\(day).hour.\(hourIndex).\(index)"
            guard !shown.contains(key) else {
                return false
            }

            shown.insert(key)
            UserDefaults.standard.set(Array(shown).sorted(), forKey: storageKey)
            nextAmbientToastAllowedAt = Date().addingTimeInterval(ambientAfterAmbientDelay)
            nextPetNeedToastAllowedAt = Date().addingTimeInterval(petNeedAfterAmbientDelay)
            showToast(
                title: petIcon(from: emojis, key: seed + index),
                subtitle: "",
                systemImageName: nil,
                duration: 3,
                action: nil,
                primaryButtonTitle: nil,
                primaryAction: nil,
                secondaryButtonTitle: nil,
                secondaryAction: nil
            )
            return true
        }

        return false
    }

    private func showWalkToastIfNeeded(at date: Date) -> Bool {
        let minute = minuteOfDay(for: date)
        guard settings.reminderScheduleMode.isActive(at: date) else {
            return false
        }

        let shown = Set(UserDefaults.standard.stringArray(forKey: walkToastStorageKey) ?? [])
        let day = dayKey(for: date)
        let walkSlots = settings.reminderScheduleMode.slotMinutes(interval: 45)
        var hasUnshownSlot = false
        var dueKeys: [String] = []

        for (slot, slotStart) in walkSlots.enumerated() {
            guard minute >= slotStart else { break }
            let key = "\(day).walk.\(slot)"
            dueKeys.append(key)
            if !shown.contains(key) {
                hasUnshownSlot = true
            }
        }

        guard hasUnshownSlot else { return false }

        var updatedShown = shown
        dueKeys.forEach { updatedShown.insert($0) }
        UserDefaults.standard.set(Array(updatedShown).sorted(), forKey: walkToastStorageKey)
        nextAmbientToastAllowedAt = Date().addingTimeInterval(ambientAfterAmbientDelay)
        nextPetNeedToastAllowedAt = Date().addingTimeInterval(petNeedAfterAmbientDelay)

        showToast(
            title: "🏃",
            subtitle: "",
            systemImageName: nil,
            duration: 3,
            action: nil,
            primaryButtonTitle: nil,
            primaryAction: nil,
            secondaryButtonTitle: nil,
            secondaryAction: nil
        )
        return true
    }

    private func showDailyEmojiToastIfNeeded(
        emoji: String,
        storageKey: String,
        startMinute: Int,
        at date: Date
    ) -> Bool {
        let key = dayKey(for: date)
        guard !shownEmojiToastDays(storageKey: storageKey).contains(key) else {
            return false
        }

        let minute = minuteOfDay(for: date)
        guard minute >= startMinute && minute < startMinute + 30 else {
            return false
        }

        var days = shownEmojiToastDays(storageKey: storageKey)
        days.insert(key)
        UserDefaults.standard.set(Array(days).sorted(), forKey: storageKey)
        showToast(
            title: emoji,
            subtitle: "",
            systemImageName: nil,
            duration: 3,
            action: nil,
            primaryButtonTitle: nil,
            primaryAction: nil,
            secondaryButtonTitle: nil,
            secondaryAction: nil
        )
        return true
    }

    private func shownEmojiToastDays(storageKey: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }

    private func randomMinuteOfDay(dayOffset: Int, startMinute: Int, endMinute: Int, at date: Date = Date()) -> Int {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let seed = abs((components.year ?? 0) * 10_000 + (components.month ?? 0) * 100 + (components.day ?? 0) + dayOffset)
        let range = max(1, endMinute - startMinute)
        return startMinute + seed % range
    }

    private func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func statusItemScreenRect() -> CGRect? {
        guard let button = statusItem.button, let window = button.window else {
            return nil
        }

        window.displayIfNeeded()
        button.superview?.layoutSubtreeIfNeeded()
        button.layoutSubtreeIfNeeded()

        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let convertedRect = window.convertToScreen(buttonRectInWindow)
        let windowRect = window.frame

        if isReasonableStatusItemRect(convertedRect) {
            return convertedRect
        }

        if isReasonableStatusItemRect(windowRect) {
            return windowRect
        }

        return nil
    }

    private func statusIconScreenCenter() -> CGPoint? {
        guard let button = statusItem.button, let window = button.window else {
            return statusItemScreenRect().map { CGPoint(x: $0.midX - 1.8, y: $0.midY) }
        }

        window.displayIfNeeded()
        button.superview?.layoutSubtreeIfNeeded()
        button.layoutSubtreeIfNeeded()

        let imageWidth = button.image?.size.width ?? 18
        let imageCenterInButton = CGPoint(
            x: min(button.bounds.midX, button.bounds.minX + imageWidth / 2 + 3),
            y: button.bounds.midY
        )
        let converted = window.convertPoint(toScreen: button.convert(imageCenterInButton, to: nil))
        if isReasonableStatusPoint(converted) {
            return CGPoint(x: converted.x - 1.8, y: converted.y)
        }

        return statusItemScreenRect().map { CGPoint(x: $0.midX - 1.8, y: $0.midY) }
    }

    private func isReasonableStatusItemRect(_ rect: CGRect) -> Bool {
        guard
            rect.origin.x.isFinite,
            rect.origin.y.isFinite,
            rect.width.isFinite,
            rect.height.isFinite,
            rect.width >= 8,
            rect.width <= 160,
            rect.height >= 8,
            rect.height <= 60
        else {
            return false
        }

        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) else {
            return false
        }

        let topBandMinY = screen.visibleFrame.maxY - 8
        return rect.midY >= topBandMinY && rect.midY <= screen.frame.maxY + 8
    }

    private func isReasonableStatusPoint(_ point: CGPoint) -> Bool {
        guard point.x.isFinite, point.y.isFinite else {
            return false
        }

        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else {
            return false
        }

        let topBandMinY = screen.visibleFrame.maxY - 8
        return point.y >= topBandMinY && point.y <= screen.frame.maxY + 8
    }

    private func petNeedScreenCenter() -> CGPoint? {
        petNeedBubbleWindow.bubbleFrameOnScreen.map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    private func triggerBlink() {
        blinkStartDate = Date()
    }

    private func triggerEatAnimation() {
        eatAnimationStartDate = Date()
        triggerBlink()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
            self?.triggerBlink()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.84) { [weak self] in
            self?.triggerBlink()
        }
    }

    private func scheduleNextBlink() {
        nextBlinkAt = Date().addingTimeInterval(TimeInterval.random(in: 2.4...5.8))
    }

    private func updateLookOffsetTowardMouse() {
        if sleepStartDate != nil || wakingStartDate != nil || isPostWakeBlinking {
            eyeLookOffset = .zero
            return
        }

        guard !session.isExerciseFlowActive else {
            eyeLookOffset = .zero
            return
        }

        guard let button = statusItem.button, let window = button.window else {
            eyeLookOffset.x *= 0.82
            eyeLookOffset.y *= 0.82
            return
        }

        let buttonCenterInWindow = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
        let buttonCenterOnScreen = window.convertPoint(toScreen: button.convert(buttonCenterInWindow, to: nil))
        let mouseLocation = NSEvent.mouseLocation
        let horizontalDistance = mouseLocation.x - buttonCenterOnScreen.x
        let verticalDistance = mouseLocation.y - buttonCenterOnScreen.y
        let targetOffset = CGPoint(
            x: max(-2.0, min(2.0, horizontalDistance / 110)),
            y: max(-1.45, min(1.0, verticalDistance / 105))
        )

        eyeLookOffset.x += (targetOffset.x - eyeLookOffset.x) * 0.34
        eyeLookOffset.y += (targetOffset.y - eyeLookOffset.y) * 0.34
    }

    private func updateIconTilt() {
        let targetTilt: CGFloat
        if shouldWiggleForExerciseReminder, let reminderStartDate {
            let elapsed = Date().timeIntervalSince(reminderStartDate)
            targetTilt = CGFloat(sin(elapsed * 2.8 * .pi)) * 15
        } else if let petNeedWiggleStartDate {
            let elapsed = Date().timeIntervalSince(petNeedWiggleStartDate)
            targetTilt = CGFloat(sin(elapsed * 2.8 * .pi)) * 15
        } else if session.isExerciseFlowActive
            || sleepStartDate != nil
            || wakingStartDate != nil
            || isPostWakeBlinking
            || isRiceFeeding
            || feedingOverlayIcon != nil
            || eatAnimationStartDate != nil {
            targetTilt = 0
        } else {
            targetTilt = isMouseHoveringStatusItem() ? 15 : 0
        }

        iconTiltDegrees += (targetTilt - iconTiltDegrees) * 0.34
        if abs(iconTiltDegrees) < 0.1 {
            iconTiltDegrees = 0
        }
    }

    private var shouldWiggleForExerciseReminder: Bool {
        session.mode == .reminding || activeToast.map(isExerciseReminderToast) == true
    }

    private func isExerciseReminderToast(_ toast: PendingToast) -> Bool {
        toast.primaryButtonTitle == "立即开始"
            && toast.secondaryButtonTitle == "稍后"
            && isExerciseReminderTitle(toast.title)
    }

    private func isExerciseReminderTitle(_ title: String) -> Bool {
        title == "时间到" || title.contains("运动")
    }

    private func isMouseHoveringStatusItem() -> Bool {
        guard let button = statusItem.button, let window = button.window else {
            return false
        }

        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectOnScreen = window.convertToScreen(buttonRectInWindow).insetBy(dx: -2, dy: -6)
        return buttonRectOnScreen.contains(NSEvent.mouseLocation)
    }

    private func updateSleepState(now: Date) {
        if let wakingStartDate, now.timeIntervalSince(wakingStartDate) >= wakeTransitionDuration {
            finishWakeTransition()
        }

        if isSleepDemoMode {
            updateSleepDemoState(now: now)
            return
        }

        if isMouseHoveringStatusItem() {
            wakeFromSleep()
            return
        }

        guard canSleep else {
            wakeFromSleep()
            return
        }

        if settings.areRemindersDisabledToday {
            enterTodayPauseSleepIfPossible(now: now)
            return
        }

        if isLunchNapTime(now) {
            if sleepStartDate == nil && wakingStartDate == nil {
                sleepStartDate = now
                sleepEndDate = nil
            }
            return
        }

        if sleepStartDate == nil, wakingStartDate == nil, now >= nextSleepAt {
            sleepStartDate = now
            sleepEndDate = now.addingTimeInterval(TimeInterval.random(in: 60...120))
        }

        if let sleepEndDate, now >= sleepEndDate {
            wakeFromSleep()
        }
    }

    private func updateSleepDemoState(now: Date) {
        if let wakingStartDate, now.timeIntervalSince(wakingStartDate) >= wakeTransitionDuration {
            finishWakeTransition()
            return
        }

        if isMouseHoveringStatusItem() {
            wakeFromSleep()
            return
        }

        if sleepStartDate == nil, wakingStartDate == nil, now >= nextSleepAt {
            hideReminderToast()
            popover.close()
            isRiceVisible = false
            currentPetNeed = nil
            reminderStartDate = nil
            petNeedWiggleStartDate = nil
            hidePetNeedBubble()
            sleepStartDate = now
            sleepEndDate = now.addingTimeInterval(10)
        }

        if let sleepEndDate, now >= sleepEndDate {
            wakeFromSleep()
        }
    }

    private var canSleep: Bool {
        session.mode == .idle
            && !isRiceVisible
            && !isRiceFeeding
            && currentPetNeed == nil
            && eatAnimationStartDate == nil
            && wakingStartDate == nil
            && !popover.isShown
            && !reminderToast.isShown
    }

    private func enterTodayPauseSleepIfPossible(now: Date = Date()) {
        guard settings.areRemindersDisabledToday, canSleep else { return }
        guard !isMouseHoveringStatusItem() else { return }
        guard sleepStartDate == nil, wakingStartDate == nil else { return }
        sleepStartDate = now
        sleepEndDate = nil
    }

    private func wakeFromSleep() {
        guard sleepStartDate != nil else { return }
        sleepEndDate = nil
        if wakingStartDate == nil {
            let now = Date()
            wakeJoltStartDate = now
            wakingStartDate = now.addingTimeInterval(wakeJoltDuration)
        }
    }

    private func finishWakeTransition() {
        sleepStartDate = nil
        sleepEndDate = nil
        wakingStartDate = nil
        wakeJoltStartDate = nil
        postWakeBlinkEndDate = Date().addingTimeInterval(0.7)
        triggerBlink()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            self?.triggerBlink()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) { [weak self] in
            self?.enterTodayPauseSleepIfPossible()
        }
        scheduleNextSleep()
    }

    private var wakeTransitionDuration: TimeInterval {
        0.82
    }

    private var wakeJoltDuration: TimeInterval {
        0.32
    }

    private var isPostWakeBlinking: Bool {
        guard let postWakeBlinkEndDate else { return false }
        if Date() >= postWakeBlinkEndDate {
            self.postWakeBlinkEndDate = nil
            return false
        }
        return true
    }

    private func isLunchNapTime(_ date: Date = Date()) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return minute >= 13 * 60 && minute < 13 * 60 + 30
    }

    private func scheduleNextSleep() {
        nextSleepAt = Date().addingTimeInterval(isSleepDemoMode ? 0.4 : TimeInterval.random(in: 7 * 60...16 * 60))
    }

    private var isSleepDemoMode: Bool {
        ProcessInfo.processInfo.environment["PET_SLEEP_DEMO"] == "1"
    }

    private var isToastDemoMode: Bool {
        ProcessInfo.processInfo.environment["TOAST_DEMO_SEQUENCE"] == "1"
    }

    private var isToastDemoLoopMode: Bool {
        ProcessInfo.processInfo.environment["TOAST_DEMO_LOOP"] == "1"
    }

    private var isFeedingOverlayDemoMode: Bool {
        ProcessInfo.processInfo.environment["PET_FEEDING_OVERLAY_DEMO"] == "1"
    }

    private var isAnyDemoMode: Bool {
        isToastDemoMode
            || isSleepDemoMode
            || isFeedingOverlayDemoMode
            || ProcessInfo.processInfo.environment["PET_NEED_DEMO_SEQUENCE"] == "1"
    }

    private func isMouseHoveringPetNeedStatusItem() -> Bool {
        guard let buttonRectOnScreen = petNeedBubbleScreenRect() else {
            return false
        }

        return buttonRectOnScreen.insetBy(dx: -6, dy: -6).contains(NSEvent.mouseLocation)
    }

    private func isMouseInsidePetNeedInteractionArea() -> Bool {
        if isMouseHoveringStatusItem() || isMouseHoveringPetNeedStatusItem() {
            return true
        }

        guard
            let statusRect = statusItemScreenRect(),
            let petNeedRect = petNeedBubbleScreenRect()
        else {
            return false
        }

        let bridgeRect = statusRect.union(petNeedRect).insetBy(dx: -8, dy: -7)
        return bridgeRect.contains(NSEvent.mouseLocation)
    }

    private func petNeedBubbleScreenRect() -> CGRect? {
        petNeedBubbleWindow.bubbleFrameOnScreen
    }

    private func currentBlinkAmount() -> CGFloat {
        guard let blinkStartDate else { return 0 }
        let duration: TimeInterval = 0.22
        let elapsed = Date().timeIntervalSince(blinkStartDate)
        if elapsed >= duration {
            self.blinkStartDate = nil
            return 0
        }

        let progress = max(0, min(1, elapsed / duration))
        return CGFloat(sin(progress * .pi))
    }

    private func statusImage(
        scale: CGFloat = 1
    ) -> NSImage {
        FlowerIcon.statusImage(
            style: iconStyle,
            tiltDegrees: iconTiltDegrees,
            scale: scale * eatAnimationScale(),
            showEyes: true,
            eyeBlinkAmount: currentBlinkAmount(),
            eyeLookOffset: session.isExerciseFlowActive ? .zero : eyeLookOffset,
            expression: expressionForCurrentState(),
            expressionYOffset: eatingEyeYOffset(),
            sleepProgress: sleepProgress(),
            wakeProgress: wakeProgress(),
            verticalOffset: wakeJoltYOffset(),
            feedingOverlayIcon: feedingOverlayIcon,
            feedingOverlayProgress: feedingOverlayProgress()
        )
    }

    private var feedingOverlayDuration: TimeInterval {
        1.05
    }

    private func feedingOverlayProgress() -> CGFloat {
        guard let feedingOverlayStartDate else { return 0 }
        let elapsed = Date().timeIntervalSince(feedingOverlayStartDate)
        return CGFloat(max(0, min(1, elapsed / feedingOverlayDuration)))
    }

    private func eatAnimationScale() -> CGFloat {
        guard let eatAnimationStartDate else { return 1 }
        let elapsed = Date().timeIntervalSince(eatAnimationStartDate)
        let duration: TimeInterval = 1.45
        if elapsed >= duration {
            self.eatAnimationStartDate = nil
            return 1
        }

        let progress = max(0, min(1, elapsed / duration))
        let biteCycles: CGFloat = 3
        let envelope = CGFloat(sin(progress * .pi))
        let bounce = abs(CGFloat(sin(progress * .pi * 2 * biteCycles)))
        return 1 + 0.18 * envelope * bounce
    }

    private func eatingEyeYOffset() -> CGFloat {
        guard let eatAnimationStartDate else { return 0 }
        let elapsed = Date().timeIntervalSince(eatAnimationStartDate)
        let duration: TimeInterval = 1.45
        if elapsed >= duration {
            return 0
        }

        let progress = max(0, min(1, elapsed / duration))
        let envelope = CGFloat(sin(progress * .pi))
        let bob = CGFloat(sin(progress * .pi * 2 * 4))
        return bob * 0.55 * envelope
    }

    private func expressionForCurrentState() -> FlowerExpression {
        if eatAnimationStartDate != nil {
            return .eating
        }

        if wakingStartDate != nil {
            return .waking
        }

        if sleepStartDate != nil {
            return .sleeping
        }

        guard session.mode == .exercising else { return .normal }
        return session.phase == .contract ? .contract : .relax
    }

    private func sleepProgress() -> CGFloat {
        guard let sleepStartDate else { return 0 }
        let elapsed = Date().timeIntervalSince(sleepStartDate)
        let cycleDuration: TimeInterval = 1.55
        return CGFloat((elapsed.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration)
    }

    private func wakeProgress() -> CGFloat {
        guard let wakingStartDate else { return 0 }
        let elapsed = Date().timeIntervalSince(wakingStartDate)
        return CGFloat(max(0, min(1, elapsed / wakeTransitionDuration)))
    }

    private func wakeJoltYOffset() -> CGFloat {
        guard let wakeJoltStartDate else { return 0 }
        let elapsed = Date().timeIntervalSince(wakeJoltStartDate)
        if elapsed >= wakeJoltDuration {
            self.wakeJoltStartDate = nil
            return 0
        }

        let progress = max(0, min(1, elapsed / wakeJoltDuration))
        let envelope = 1 - CGFloat(progress)
        return sin(CGFloat(progress) * .pi * 4) * 1.1 * envelope
    }
}

extension StatusCoordinator: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            if notification.object as? NSPopover === self?.actionPopover {
                self?.activeToast = nil
            }
            self?.showNextPendingToastIfPossible()
        }
    }
}

private final class CheckInMenuHeaderView: NSView {
    private let summary: DailyCheckInSummary

    init(summary: DailyCheckInSummary) {
        self.summary = summary
        super.init(frame: CGRect(x: 0, y: 0, width: 280, height: 86))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let left: CGFloat = 18
        let muted = NSColor.secondaryLabelColor
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: muted
        ]
        "今日打卡 \(summary.todayCount)/\(summary.totalCount)".draw(
            at: CGPoint(x: left, y: 59),
            withAttributes: titleAttributes
        )

        let dotRadius: CGFloat = 4
        let dotGap: CGFloat = 4
        var dotX = left + dotRadius
        let dotY: CGFloat = 39
        for completed in summary.completedSlots {
            (completed ? NSColor.systemGreen : NSColor.tertiaryLabelColor).setFill()
            NSBezierPath(
                ovalIn: CGRect(
                    x: dotX - dotRadius,
                    y: dotY - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
            ).fill()
            dotX += dotRadius * 2 + dotGap
        }

        let comparisonAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: muted
        ]
        summary.comparisonText.draw(
            at: CGPoint(x: left, y: 13),
            withAttributes: comparisonAttributes
        )
    }
}

private final class VersionMenuItemView: NSView {
    private let version: String
    private let updateVersion: String
    private let action: () -> Void
    private var isHovering = false

    init(version: String, updateVersion: String, action: @escaping () -> Void) {
        self.version = version
        self.updateVersion = updateVersion
        self.action = action
        super.init(frame: CGRect(x: 0, y: 0, width: 280, height: 26))
        wantsLayer = true
        setAccessibilityLabel("版本 \(version)，有新版本 \(updateVersion)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        enclosingMenuItem?.menu?.cancelTracking()
        DispatchQueue.main.async { [action] in
            action()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isHovering {
            NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
            NSBezierPath(rect: bounds).fill()
        }

        let text = "版本 \(version)"
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: isHovering ? NSColor.selectedMenuItemTextColor : NSColor.labelColor
        ]
        let textSize = text.size(withAttributes: textAttributes)
        let textPoint = CGPoint(x: 18, y: (bounds.height - textSize.height) / 2)
        text.draw(at: textPoint, withAttributes: textAttributes)

        let arrowText = "›"
        let arrowAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: isHovering ? NSColor.selectedMenuItemTextColor : NSColor.secondaryLabelColor
        ]
        let arrowSize = arrowText.size(withAttributes: arrowAttributes)
        let arrowPoint = CGPoint(
            x: bounds.width - arrowSize.width - 18,
            y: (bounds.height - arrowSize.height) / 2 - 1
        )
        arrowText.draw(at: arrowPoint, withAttributes: arrowAttributes)

        let badgeText = "更新"
        let badgeFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
        let badgeAttributes: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: NSColor.white
        ]
        let badgeTextSize = badgeText.size(withAttributes: badgeAttributes)
        let badgeWidth = max(34, badgeTextSize.width + 14)
        let badgeHeight: CGFloat = 18
        let badgeX = arrowPoint.x - badgeWidth - 10
        let badgeRect = CGRect(
            x: badgeX,
            y: (bounds.height - badgeHeight) / 2,
            width: badgeWidth,
            height: badgeHeight
        )

        NSColor.systemRed.setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 9, yRadius: 9).fill()

        let badgePoint = CGPoint(
            x: badgeRect.midX - badgeTextSize.width / 2,
            y: badgeRect.midY - badgeTextSize.height / 2
        )
        badgeText.draw(at: badgePoint, withAttributes: badgeAttributes)
    }
}
