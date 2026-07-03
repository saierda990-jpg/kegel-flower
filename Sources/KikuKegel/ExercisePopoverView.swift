import SwiftUI

struct ExercisePopoverView: View {
    @ObservedObject var session: KegelSession
    @ObservedObject var petStatusStore: PetStatusStore
    @ObservedObject var noticeStore: PopoverNoticeStore
    let iconStyle: () -> FlowerIconStyle
    let petStatus: () -> PetStatusSnapshot
    let startNow: () -> Void
    let snooze: () -> Void
    let feedPet: () -> String?
    let drinkPet: () -> String?
    let restPet: () -> String?
    let toiletPet: () -> String?

    @State private var selectedTab: PopoverTab = .kegel
    @State private var refreshDate = Date()
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            NativeVisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if let notice = noticeStore.notice {
                    popoverNoticeContent(notice)
                } else {
                    tabSwitch

                    Group {
                        switch selectedTab {
                        case .kegel:
                            kegelContent
                        case .pet:
                            petContent
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .frame(width: 300, height: 232)
        .onAppear {
            refreshDate = Date()
        }
        .onReceive(refreshTimer) { date in
            refreshDate = date
        }
    }

    private func popoverNoticeContent(_ notice: PopoverActionNotice) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            if notice.layout == .petAction {
                Text(notice.title)
                    .font(.system(size: 40))
                    .frame(height: 48)
            } else {
                HStack(spacing: 8) {
                    if let systemImageName = notice.systemImageName {
                        Image(systemName: systemImageName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 4) {
                        Text(notice.title)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        if !notice.subtitle.isEmpty {
                            Text(notice.subtitle)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                if let primaryButtonTitle = notice.primaryButtonTitle {
                    Button(primaryButtonTitle) {
                        notice.primaryAction?()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
                }

                if let secondaryButtonTitle = notice.secondaryButtonTitle {
                    Button(secondaryButtonTitle) {
                        notice.secondaryAction?()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pixelScreenBackground: some View {
        ZStack {
            Color.black.opacity(0.08)
            PixelGridBackground()
                .opacity(0.12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tabSwitch: some View {
        return HStack(spacing: 6) {
            tabButton("提肛", tab: .kegel)
            tabButton("状态", tab: .pet)
        }
        .padding(3)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.08), in: Capsule())
    }

    private func tabButton(_ title: String, tab: PopoverTab) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
        .frame(maxWidth: .infinity)
        .background(selectedTab == tab ? Color.primary.opacity(0.16) : Color.clear, in: Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            selectedTab = tab
        }
    }

    private var kegelContent: some View {
        VStack(spacing: 0) {
            kegelMainCanvas
                .frame(height: 122, alignment: .top)

            Spacer(minLength: 0)

            if session.mode != .preparing && session.mode != .completing {
                kegelActionButtons
                    .frame(height: 34, alignment: .bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var kegelMainCanvas: some View {
        Group {
            if session.mode == .exercising {
                compactExerciseCanvas
            } else {
                defaultKegelCanvas
            }
        }
    }

    private var defaultKegelCanvas: some View {
        VStack(spacing: 16) {
            kegelHeader

            if session.mode == .preparing || session.mode == .completing {
                Text(session.mode == .preparing ? "准备跟随节奏。" : "本次练习已完成。")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 22, alignment: .topLeading)
            } else {
                Text(nextReminderText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 22, alignment: .topLeading)
            }
        }
    }

    private var compactExerciseCanvas: some View {
        VStack(spacing: 10) {
            kegelHeader
                .frame(height: 64, alignment: .center)

            exerciseProgress
        }
    }

    private var kegelActionButtons: some View {
        HStack(spacing: 10) {
            Button(primaryButtonTitle) {
                startNow()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.defaultAction)

            Button("稍后") {
                snooze()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Spacer()
        }
    }

    private var kegelHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.18))
                FlowerMark(
                    style: iconStyle(),
                    phase: session.phase,
                    isAnimating: session.mode == .exercising
                )
                .padding(kegelMarkPadding)
            }
            .frame(width: kegelIconSize, height: kegelIconSize)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: kegelTitleSize, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: kegelSubtitleSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var exerciseProgress: some View {
        VStack(spacing: 10) {
            GradientProgressBar(
                value: progress,
                colors: [
                    Color.white.opacity(0.82),
                    Color.white.opacity(0.92),
                    Color.white
                ]
            )

            HStack {
                Text("第 \(min(session.completedCycles + 1, session.totalCycles)) / \(session.totalCycles) 组")
                Spacer()
                Text(formatSeconds(session.remainingExerciseSeconds))
                    .monospacedDigit()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .frame(height: 48, alignment: .top)
    }

    private var petContent: some View {
        let snapshot = petStatus()
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.18))
                    FlowerMark(
                        style: iconStyle(),
                        phase: .relax,
                        isAnimating: false
                    )
                    .padding(8)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Lv.\(snapshot.level) 小花")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("经验 \(snapshot.experience)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                Text(snapshot.moodText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(height: 28)
                    .frame(width: 78, alignment: .center)
            }
            .padding(.top, 2)

            VStack(spacing: 10) {
                PetStatusRow(
                    title: "饱腹",
                    value: snapshot.fullness,
                    gradient: [
                        Color.white.opacity(0.82),
                        Color.white.opacity(0.92),
                        Color.white
                    ],
                    detail: percentText(snapshot.fullness)
                )
                PetStatusRow(
                    title: "水分",
                    value: snapshot.hydration,
                    gradient: [
                        Color.white.opacity(0.82),
                        Color.white.opacity(0.92),
                        Color.white
                    ],
                    detail: snapshot.hydrationDetail
                )
                PetStatusRow(
                    title: "运动",
                    value: snapshot.exercise,
                    gradient: [
                        Color.white.opacity(0.82),
                        Color.white.opacity(0.92),
                        Color.white
                    ],
                    detail: snapshot.exerciseDetail
                )
            }

            Spacer(minLength: 0)
        }
    }

    private enum PopoverTab {
        case kegel
        case pet
    }

    private var title: String {
        switch session.mode {
        case .idle:
            return "下一次提肛"
        case .reminding:
            return "到时间了"
        case .preparing:
            return session.transitionText
        case .exercising:
            return session.phase.rawValue
        case .completing:
            return "完成"
        }
    }

    private var subtitle: String {
        switch session.mode {
        case .idle:
            let minutes = Int(session.timing.reminderInterval / 60)
            return "每 \(minutes) 分钟提醒一次。"
        case .reminding:
            return "点击开始后，跟着小花的节奏收缩和放松。"
        case .preparing:
            return session.transitionText == "开始" ? "现在开始。" : "先准备好呼吸。"
        case .exercising:
            return session.phase == .contract ? "轻柔收紧，保持呼吸。" : "完全放松，准备下一次。"
        case .completing:
            return "真棒，已经完成这一次。"
        }
    }

    private var primaryButtonTitle: String {
        session.mode == .exercising ? "重新开始" : "开始"
    }

    private var kegelIconSize: CGFloat {
        session.mode == .exercising ? 64 : 82
    }

    private var kegelMarkPadding: CGFloat {
        session.mode == .exercising ? 14 : 16
    }

    private var kegelTitleSize: CGFloat {
        session.mode == .exercising ? 17 : 19
    }

    private var kegelSubtitleSize: CGFloat {
        session.mode == .exercising ? 12 : 13
    }

    private var nextReminderText: String {
        let minutes = max(1, Int(ceil(session.nextReminderAt.timeIntervalSince(refreshDate) / 60)))
        return "\(minutes) 分钟后提醒。"
    }

    private var progress: Double {
        let remaining = Double(session.remainingExerciseSeconds)
        let total = Double(session.totalExerciseSeconds)
        guard total > 0 else { return 0 }
        return max(0, min(1, 1 - remaining / total))
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func percentText(_ value: Double) -> String {
        "\(Int(round(max(0, min(1, value)) * 100)))%"
    }
}

private struct PetStatusRow: View {
    let title: String
    let value: Double
    let gradient: [Color]
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)

            GradientProgressBar(value: value, colors: gradient)
                .frame(maxWidth: .infinity)

            Text(detail)
                .font(.system(size: 13.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
                .frame(width: 94, alignment: .trailing)
        }
    }
}

private struct GradientProgressBar: View {
    let value: Double
    let colors: [Color]
    @State private var displayedValue = 0.0

    private var clampedValue: Double {
        max(0, min(1, value))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )

                if displayedValue > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * displayedValue))
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.22),
                                            Color.white.opacity(0.04),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .blendMode(.screen)
                        )
                }
            }
        }
        .frame(height: 8)
        .onAppear {
            displayedValue = clampedValue
        }
        .onChange(of: clampedValue) { newValue in
            withAnimation(.easeOut(duration: 0.78)) {
                displayedValue = newValue
            }
        }
    }
}

private struct PixelButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind
    var isSmall = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isSmall ? 11 : 13, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, isSmall ? 8 : 13)
            .padding(.vertical, isSmall ? 5 : 8)
            .background(
                Rectangle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(kind == .primary ? 0.55 : 0.30), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 0, x: 2, y: 2)
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
            .contentShape(Rectangle())
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch kind {
        case .primary:
            return isPressed ? Color.white.opacity(0.24) : Color.white.opacity(0.17)
        case .secondary:
            return isPressed ? Color.white.opacity(0.16) : Color.white.opacity(0.10)
        }
    }
}

private struct PixelPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color.black.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
}

private struct PixelIconPlate: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.black.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)
    }
}

private struct PixelGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 8
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 0.5)
        }
    }
}
