import AppKit
import SwiftUI

final class ToastBubbleWindow: NSPanel {
    var onClose: (() -> Void)?

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

    override var canBecomeKey: Bool { true }
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

        let controller = NSHostingController(
            rootView: ReminderToastView(
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
        )
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        contentViewController = controller

        let screen = Self.screen(for: statusRect) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? screen?.frame ?? .zero
        let gap: CGFloat = 7
        var origin = CGPoint(
            x: statusRect.midX - size.width / 2,
            y: statusRect.minY - size.height - gap
        )

        if visibleFrame != .zero {
            origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
            origin.y = visibleFrame.maxY - size.height - gap
        }

        setFrame(CGRect(origin: origin, size: size), display: true)
        orderFrontRegardless()
    }

    private static func screen(for statusRect: CGRect) -> NSScreen? {
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: statusRect.midX, y: $0.frame.midY)) }) {
            return screen
        }

        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.screens.first { $0.frame.intersects(statusRect) }
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
