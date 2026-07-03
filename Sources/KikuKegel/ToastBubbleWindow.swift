import AppKit
import SwiftUI

final class ToastBubbleWindow: NSPanel {
    var onClose: (() -> Void)?
    private var hostingController: NSHostingController<ReminderToastView>?

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 220, height: 92),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        ignoresMouseEvents = false
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(
        title: String,
        subtitle: String,
        systemImageName: String?,
        layout: ToastLayout,
        action: (() -> Void)?,
        primaryButtonTitle: String?,
        primaryAction: (() -> Void)?,
        secondaryButtonTitle: String?,
        secondaryAction: (() -> Void)?,
        near statusRect: CGRect
    ) {
        let size = toastSize(
            title: title,
            subtitle: subtitle,
            layout: layout,
            primaryButtonTitle: primaryButtonTitle
        )

        let wrappedPrimaryAction: (() -> Void)? = primaryAction.map { [weak self] action in
            {
                action()
                self?.hide()
            }
        }
        let wrappedSecondaryAction: (() -> Void)? = secondaryAction.map { [weak self] action in
            {
                action()
                self?.hide()
            }
        }

        let rootView = ReminderToastView(
            title: title,
            subtitle: subtitle,
            systemImageName: systemImageName,
            layout: layout,
            action: action.map { [weak self] action in
                {
                    action()
                    self?.hide()
                }
            },
            primaryButtonTitle: primaryButtonTitle,
            primaryAction: wrappedPrimaryAction,
            secondaryButtonTitle: secondaryButtonTitle,
            secondaryAction: wrappedSecondaryAction
        )
        let controller = NSHostingController(rootView: rootView)
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        controller.view.layer?.isOpaque = false
        controller.view.layer?.masksToBounds = false
        hostingController = controller

        let container = ToastBubbleContainerView(
            frame: CGRect(origin: .zero, size: size),
            bodyCornerRadius: rootView.bodyCornerRadius,
            arrowSize: rootView.arrowSize
        )
        controller.view.frame = container.bounds
        controller.view.autoresizingMask = [.width, .height]
        container.addSubview(controller.view)
        contentView = container

        guard let origin = anchoredOrigin(for: size, near: statusRect) else {
            return
        }

        setFrame(CGRect(origin: origin, size: size), display: true)
        orderFrontRegardless()
    }

    func reposition(near statusRect: CGRect) {
        guard isVisible else { return }
        guard let origin = anchoredOrigin(for: frame.size, near: statusRect) else {
            hide()
            return
        }
        setFrameOrigin(origin)
    }

    private func anchoredOrigin(for size: NSSize, near statusRect: CGRect) -> CGPoint? {
        guard
            let screen = Self.screen(for: statusRect),
            Self.isPlausibleMenuBarAnchor(statusRect, on: screen)
        else {
            return nil
        }

        let visibleFrame = screen.visibleFrame
        let gap: CGFloat = 3.5
        var origin = CGPoint(
            x: statusRect.midX - size.width / 2,
            y: statusRect.minY - size.height - gap
        )

        origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
        origin.y = min(max(origin.y, visibleFrame.minY + 8), visibleFrame.maxY - size.height - gap)

        return origin
    }

    private static func screen(for statusRect: CGRect) -> NSScreen? {
        let midpoint = CGPoint(x: statusRect.midX, y: statusRect.midY)
        return NSScreen.screens.first { $0.frame.contains(midpoint) }
            ?? NSScreen.screens.first { $0.frame.intersects(statusRect) }
    }

    private static func isPlausibleMenuBarAnchor(_ rect: CGRect, on screen: NSScreen) -> Bool {
        guard
            rect.origin.x.isFinite,
            rect.origin.y.isFinite,
            rect.width.isFinite,
            rect.height.isFinite,
            rect.width >= 8,
            rect.width <= 180,
            rect.height >= 8,
            rect.height <= 60
        else {
            return false
        }

        let topBandMinY = screen.visibleFrame.maxY - 24
        return rect.midY >= topBandMinY && rect.midY <= screen.frame.maxY + 12
    }

    private func toastSize(
        title: String,
        subtitle: String,
        layout: ToastLayout,
        primaryButtonTitle: String?
    ) -> NSSize {
        if layout == .petAction {
            return NSSize(width: 96, height: 101)
        }

        if primaryButtonTitle != nil {
            let titleWidth = CGFloat(title.count) * 13 + 34
            return NSSize(width: min(220, max(167, titleWidth)), height: 77)
        }

        let titleWidth = CGFloat(title.count) * 11 + 25
        let subtitleWidth = subtitle.isEmpty ? 0 : CGFloat(subtitle.count) * 8 + 27
        let bodyWidth = min(155, max(76, max(titleWidth, subtitleWidth) * 1.16))
        let bodyHeight: CGFloat = subtitle.isEmpty ? 34 : 44
        return NSSize(width: bodyWidth, height: bodyHeight + 6)
    }

    func hide() {
        orderOut(nil)
        onClose?()
    }

    var isShown: Bool {
        isVisible
    }

    var centerOnScreen: CGPoint? {
        guard isVisible || frame != .zero else { return nil }
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}

private final class ToastBubbleContainerView: NSView {
    private let bodyCornerRadius: CGFloat
    private let arrowSize: CGSize
    private let bodyEffectView = NSVisualEffectView()
    private let arrowEffectView = NSVisualEffectView()

    init(frame: CGRect, bodyCornerRadius: CGFloat, arrowSize: CGSize) {
        self.bodyCornerRadius = bodyCornerRadius
        self.arrowSize = arrowSize
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupEffectView(bodyEffectView)
        setupEffectView(arrowEffectView)
        addSubview(arrowEffectView)
        addSubview(bodyEffectView)

        shadow = NSShadow()
        shadow?.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow?.shadowBlurRadius = 10
        shadow?.shadowOffset = NSSize(width: 0, height: -5)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let arrowHeight = arrowSize.height
        let bodyFrame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - arrowHeight)
        let arrowFrame = CGRect(
            x: (bounds.width - arrowSize.width) / 2,
            y: bodyFrame.maxY - 0.5,
            width: arrowSize.width,
            height: arrowHeight + 0.5
        )

        bodyEffectView.frame = bodyFrame
        arrowEffectView.frame = arrowFrame

        let bodyMaskPath = CGPath(
            roundedRect: bodyEffectView.bounds,
            cornerWidth: bodyCornerRadius,
            cornerHeight: bodyCornerRadius,
            transform: nil
        )
        bodyEffectView.layer?.mask = shapeMask(path: bodyMaskPath, frame: bodyEffectView.bounds)

        let arrowMaskPath = CGMutablePath()
        arrowMaskPath.move(to: CGPoint(x: arrowEffectView.bounds.midX, y: arrowEffectView.bounds.maxY))
        arrowMaskPath.addLine(to: CGPoint(x: arrowEffectView.bounds.maxX, y: arrowEffectView.bounds.minY))
        arrowMaskPath.addLine(to: CGPoint(x: arrowEffectView.bounds.minX, y: arrowEffectView.bounds.minY))
        arrowMaskPath.closeSubpath()
        arrowEffectView.layer?.mask = shapeMask(path: arrowMaskPath, frame: arrowEffectView.bounds)
    }

    private func setupEffectView(_ view: NSVisualEffectView) {
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func shapeMask(path: CGPath, frame: CGRect) -> CAShapeLayer {
        let mask = CAShapeLayer()
        mask.frame = frame
        mask.path = path
        mask.fillColor = NSColor.black.cgColor
        return mask
    }
}
