import AppKit

final class RiceFeedAnimationWindow: NSWindow {
    private let label = NSTextField(labelWithString: "🍚")
    private var startFrame = CGRect.zero
    private var endCenter = CGPoint.zero
    private var startedAt = Date()
    private var displayLink: Timer?
    private var completion: (() -> Void)?

    init() {
        let frame = CGRect(x: 0, y: 0, width: 38, height: 38)
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        ignoresMouseEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        label.font = .systemFont(ofSize: 28)
        label.alignment = .center
        label.frame = CGRect(origin: .zero, size: frame.size)
        contentView = label
    }

    func play(icon: String, from startCenter: CGPoint, to endCenter: CGPoint, completion: @escaping () -> Void) {
        guard startCenter.isSafeScreenPoint, endCenter.isSafeScreenPoint else {
            orderOut(nil)
            displayLink?.invalidate()
            displayLink = nil
            completion()
            return
        }

        displayLink?.invalidate()
        label.stringValue = icon
        self.endCenter = endCenter
        self.completion = completion
        startedAt = Date()

        let startSize = CGSize(width: 42, height: 42)
        startFrame = CGRect(
            x: startCenter.x - startSize.width / 2,
            y: startCenter.y - startSize.height / 2,
            width: startSize.width,
            height: startSize.height
        )
        setFrame(startFrame, display: true)
        label.alphaValue = 1
        label.font = .systemFont(ofSize: 30)
        orderFront(nil)

        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.advance()
        }
    }

    private func advance() {
        let duration: TimeInterval = 0.88
        let progress = max(0, min(1, Date().timeIntervalSince(startedAt) / duration))
        let eased = 1 - pow(1 - progress, 3)

        let startCenter = CGPoint(x: startFrame.midX, y: startFrame.midY)
        let currentCenter = CGPoint(
            x: startCenter.x + (endCenter.x - startCenter.x) * eased,
            y: startCenter.y + (endCenter.y - startCenter.y) * eased
        )
        let size = 42 - 26 * eased
        let frame = CGRect(
            x: currentCenter.x - size / 2,
            y: currentCenter.y - size / 2,
            width: size,
            height: size
        )

        guard frame.isSafeWindowFrame else {
            displayLink?.invalidate()
            displayLink = nil
            orderOut(nil)
            completion?()
            completion = nil
            return
        }

        setFrame(frame, display: true)
        label.frame = CGRect(origin: .zero, size: frame.size)
        label.font = .systemFont(ofSize: max(10, 30 - 19 * eased))
        label.alphaValue = 1 - 0.35 * eased

        if progress >= 1 {
            displayLink?.invalidate()
            displayLink = nil
            orderOut(nil)
            completion?()
            completion = nil
        }
    }
}

private extension CGPoint {
    var isSafeScreenPoint: Bool {
        x.isFinite && y.isFinite && abs(x) < 100_000 && abs(y) < 100_000
    }
}

private extension CGRect {
    var isSafeWindowFrame: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
            && size.width > 0
            && size.height > 0
            && abs(origin.x) < 100_000
            && abs(origin.y) < 100_000
    }
}
