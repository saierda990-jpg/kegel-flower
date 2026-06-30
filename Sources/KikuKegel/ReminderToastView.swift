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

    var body: some View {
        VStack(spacing: 0) {
            toastArrow
                .offset(y: 1)

            contentBody
        }
        .contentShape(Rectangle())
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
        .background(toastMaterial(cornerRadius: primaryButtonTitle == nil ? 16 : 18))
        .overlay(toastBorder(cornerRadius: primaryButtonTitle == nil ? 16 : 18))
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
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
                        .frame(width: 62, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: bodyWidth, height: bodyHeight)
        .background(toastMaterial(cornerRadius: 19))
        .overlay(toastBorder(cornerRadius: 19))
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    private var toastArrow: some View {
        let size = CGSize(
            width: primaryButtonTitle == nil ? 13 : 17,
            height: primaryButtonTitle == nil ? 6 : 9
        )

        return ToastArrow()
            .fill(.regularMaterial)
            .overlay(ToastArrow().fill(Color.primary.opacity(0.035)))
        .frame(width: size.width, height: size.height)
        .overlay(
            ToastArrow()
                .stroke(Color.primary.opacity(0.18), lineWidth: 0.8)
        )
    }

    private func toastMaterial(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
    }

    private func toastBorder(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.primary.opacity(0.18), lineWidth: 0.8)
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

private struct ToastArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
