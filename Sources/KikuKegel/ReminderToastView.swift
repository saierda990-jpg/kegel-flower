import SwiftUI

enum ToastLayout {
    case compact
    case standardAction
    case petAction
}

struct ReminderToastView: View {
    let title: String
    let subtitle: String
    let systemImageName: String?
    let layout: ToastLayout
    let action: (() -> Void)?
    let primaryButtonTitle: String?
    let primaryAction: (() -> Void)?
    let secondaryButtonTitle: String?
    let secondaryAction: (() -> Void)?
    var showsArrow: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if showsArrow {
                Color.clear
                    .frame(width: arrowSize.width, height: arrowSize.height)
            }

            contentBody
        }
        .contentShape(Rectangle())
        .background(Color.clear)
        .onTapGesture {
            if primaryButtonTitle == nil {
                action?()
            }
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if layout == .petAction {
            petActionBody
        } else {
            standardBody
        }
    }

    private var standardBody: some View {
        VStack(alignment: .center, spacing: primaryButtonTitle == nil ? 5 : 7) {
            HStack(spacing: 5) {
                if let systemImageName {
                    Image(systemName: systemImageName)
                        .font(.system(size: primaryButtonTitle == nil ? 10 : 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .center, spacing: 2) {
                    Text(title)
                        .font(.system(size: standardTitleFontSize, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: primaryButtonTitle == nil ? 8 : 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let primaryButtonTitle {
                HStack(spacing: 7) {
                    Button {
                        primaryAction?()
                    } label: {
                        Text(primaryButtonTitle)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.mini)

                    if let secondaryButtonTitle {
                        Button {
                            secondaryAction?()
                        } label: {
                            Text(secondaryButtonTitle)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
        }
        .padding(.horizontal, primaryButtonTitle == nil ? 10 : 13)
        .padding(.vertical, primaryButtonTitle == nil ? 5 : 11)
        .frame(width: bodyWidth, height: bodyHeight)
    }

    private var petActionBody: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 29))
                .frame(height: 34)
                .lineLimit(1)

            if let primaryButtonTitle {
                Button {
                    primaryAction?()
                } label: {
                    Text(primaryButtonTitle)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 24)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: bodyWidth, height: bodyHeight)
    }

    var arrowSize: CGSize {
        CGSize(
            width: primaryButtonTitle == nil ? 7 : 9,
            height: primaryButtonTitle == nil ? 3 : 5
        )
    }

    var bodyCornerRadius: CGFloat {
        if layout == .petAction {
            return 19
        }
        return primaryButtonTitle == nil ? 16 : 18
    }

    private var bodyHeight: CGFloat {
        if layout == .petAction {
            return 92
        }
        if primaryButtonTitle != nil {
            return 68
        }
        return subtitle.isEmpty ? 34 : 44
    }

    private var bodyWidth: CGFloat {
        if layout == .petAction {
            return 96
        }
        if primaryButtonTitle != nil {
            let titleWidth = CGFloat(title.count) * 13 + 34
            return min(220, max(167, titleWidth))
        }

        let titleWidth = CGFloat(title.count) * 11 + 25
        let subtitleWidth = subtitle.isEmpty ? 0 : CGFloat(subtitle.count) * 8 + 27
        return min(155, max(76, max(titleWidth, subtitleWidth) * 1.16))
    }

    private var standardTitleFontSize: CGFloat {
        primaryButtonTitle == nil && subtitle.isEmpty ? 18 : (primaryButtonTitle == nil ? 11 : 13)
    }
}
