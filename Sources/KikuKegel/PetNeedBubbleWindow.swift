import AppKit

final class PetNeedBubbleWindow: NSPanel {
    private static let bubbleSize = CGSize(width: 40, height: 22)
    private let bubbleView = PetNeedBubbleView(frame: CGRect(origin: .zero, size: PetNeedBubbleWindow.bubbleSize))

    var onClick: (() -> Void)? {
        didSet {
            bubbleView.onClick = onClick
        }
    }

    init() {
        super.init(
            contentRect: CGRect(origin: .zero, size: Self.bubbleSize),
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
        contentView = bubbleView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(icon: String, near statusRect: CGRect) {
        bubbleView.icon = icon

        let screen = NSScreen.screens.first { $0.frame.intersects(statusRect) } ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero
        let gap: CGFloat = 6
        var origin = CGPoint(
            x: statusRect.minX - Self.bubbleSize.width - gap,
            y: statusRect.midY - Self.bubbleSize.height / 2
        )

        if screenFrame != .zero {
            if origin.x < screenFrame.minX + 6 {
                origin.x = statusRect.maxX + gap
            }
            origin.y = min(origin.y, screenFrame.maxY - Self.bubbleSize.height - 2)
            origin.y = max(origin.y, screenFrame.minY + 2)
        }

        setFrame(CGRect(origin: origin, size: Self.bubbleSize), display: true)
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    var bubbleFrameOnScreen: CGRect? {
        isVisible ? frame : nil
    }
}

private final class PetNeedBubbleView: NSControl {
    var icon = "🍚" {
        didSet {
            needsDisplay = true
        }
    }

    var onClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let capsuleRect = bounds.insetBy(dx: 1, dy: 1)
        let capsulePath = NSBezierPath(
            roundedRect: capsuleRect,
            xRadius: capsuleRect.height / 2,
            yRadius: capsuleRect.height / 2
        )
        NSColor.black.withAlphaComponent(0.60).setFill()
        capsulePath.fill()

        let font = NSFont(name: "Apple Color Emoji", size: 15) ?? .systemFont(ofSize: 15)
        let text = NSAttributedString(string: icon, attributes: [.font: font])
        let textSize = text.size()
        let textRect = CGRect(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2 + 0.5,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect)
    }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        onClick?()
    }
}
