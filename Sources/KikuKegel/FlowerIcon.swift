import AppKit
import SwiftUI

enum FlowerIconStyle: String, CaseIterable {
    case fourPetal = "四瓣小花"
    case sixPetal = "六瓣小花"
    case ring = "圆环"
}

enum FlowerExpression {
    case normal
    case contract
    case relax
    case eating
    case sleeping
    case waking
}

enum FlowerIcon {
    static func statusImage(
        style: FlowerIconStyle,
        rotationDegrees: CGFloat = 0,
        tiltDegrees: CGFloat = 0,
        scale: CGFloat = 1,
        showEyes: Bool = false,
        eyeBlinkAmount: CGFloat = 0,
        eyeLookOffset: CGPoint = .zero,
        expression: FlowerExpression = .normal,
        expressionYOffset: CGFloat = 0,
        sleepProgress: CGFloat = 0,
        wakeProgress: CGFloat = 0,
        verticalOffset: CGFloat = 0
    ) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.white.setFill()
        NSColor.white.setStroke()

        NSGraphicsContext.saveGraphicsState()
        let baseTransform = NSAffineTransform()
        baseTransform.translateX(by: 0, yBy: verticalOffset)
        baseTransform.concat()

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: size.width / 2, yBy: size.height / 2)
        transform.rotate(byDegrees: tiltDegrees)
        transform.rotate(byDegrees: rotationDegrees)
        transform.scale(by: scale)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()

        switch style {
        case .fourPetal:
            drawSoftFourPetal(size: size)
        case .sixPetal:
            drawPetals(count: 6, size: size, petalSize: NSSize(width: 7.0, height: 9.4))
        case .ring:
            drawRing(size: size)
        }

        NSGraphicsContext.restoreGraphicsState()

        if showEyes {
            drawExpression(
                expression,
                size: size,
                tiltDegrees: tiltDegrees,
                scale: scale,
                blinkAmount: eyeBlinkAmount,
                lookOffset: eyeLookOffset,
                expressionYOffset: expressionYOffset,
                sleepProgress: sleepProgress,
                wakeProgress: wakeProgress
            )
        }

        NSGraphicsContext.restoreGraphicsState()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawPetals(count: Int, size: NSSize, petalSize: NSSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius: CGFloat = count == 4 ? 4.0 : 4.6

        for index in 0..<count {
            let angle = (CGFloat(index) / CGFloat(count)) * .pi * 2
            let petalCenter = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            let rect = CGRect(
                x: petalCenter.x - petalSize.width / 2,
                y: petalCenter.y - petalSize.height / 2,
                width: petalSize.width,
                height: petalSize.height
            )
            NSBezierPath(ovalIn: rect).fill()
        }

        NSBezierPath(ovalIn: CGRect(x: center.x - 2.9, y: center.y - 2.9, width: 5.8, height: 5.8)).fill()
    }

    private static func drawSoftFourPetal(size: NSSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let petalSize = CGSize(width: 10.4, height: 10.4)
        let offset: CGFloat = 3.15

        for petalCenter in [
            CGPoint(x: center.x - offset, y: center.y + offset),
            CGPoint(x: center.x + offset, y: center.y + offset),
            CGPoint(x: center.x - offset, y: center.y - offset),
            CGPoint(x: center.x + offset, y: center.y - offset)
        ] {
            let rect = CGRect(
                x: petalCenter.x - petalSize.width / 2,
                y: petalCenter.y - petalSize.height / 2,
                width: petalSize.width,
                height: petalSize.height
            )
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    private static func drawRing(size: NSSize) {
        let ring = NSBezierPath(ovalIn: CGRect(x: 4.2, y: 4.2, width: size.width - 8.4, height: size.height - 8.4))
        ring.lineWidth = 3
        ring.stroke()
    }

    private static func drawExpression(
        _ expression: FlowerExpression,
        size: NSSize,
        tiltDegrees: CGFloat,
        scale: CGFloat,
        blinkAmount: CGFloat,
        lookOffset: CGPoint,
        expressionYOffset: CGFloat,
        sleepProgress: CGFloat,
        wakeProgress: CGFloat
    ) {
        switch expression {
        case .normal:
            drawNormalEyes(size: size, tiltDegrees: tiltDegrees, scale: scale, blinkAmount: blinkAmount, lookOffset: lookOffset)
        case .contract:
            drawContractExpression(size: size, tiltDegrees: tiltDegrees, scale: scale)
        case .relax:
            drawRelaxExpression(size: size, tiltDegrees: tiltDegrees, scale: scale)
        case .eating:
            drawEatingExpression(size: size, tiltDegrees: tiltDegrees, scale: scale, yOffset: expressionYOffset)
        case .sleeping:
            drawSleepingExpression(size: size, tiltDegrees: tiltDegrees, scale: scale, progress: sleepProgress)
        case .waking:
            drawWakingExpression(size: size, tiltDegrees: tiltDegrees, scale: scale, progress: wakeProgress, sleepProgress: sleepProgress)
        }
    }

    private static func drawNormalEyes(size: NSSize, tiltDegrees: CGFloat, scale: CGFloat, blinkAmount: CGFloat, lookOffset: CGPoint) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let blink = max(0, min(1, blinkAmount))
        let eyeHeight = max(0.85, 4.9 * (1 - blink))
        let eyeWidth = 1.75 + 1.15 * blink
        let baseY = center.y + 0.55
        let xOffset = max(-2.0, min(2.0, lookOffset.x))
        let yOffset = max(-1.45, min(1.0, lookOffset.y))

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: tiltDegrees)
        transform.scale(by: scale)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()

        NSGraphicsContext.current?.compositingOperation = .clear
        NSColor.clear.setFill()

        for baseX in [center.x - 2.65, center.x + 2.65] {
            let rect = CGRect(
                x: baseX + xOffset - eyeWidth / 2,
                y: baseY + yOffset - eyeHeight / 2,
                width: eyeWidth,
                height: eyeHeight
            )
            NSBezierPath(roundedRect: rect, xRadius: eyeWidth / 2, yRadius: eyeWidth / 2).fill()
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawContractExpression(size: NSSize, tiltDegrees: CGFloat, scale: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        withClearFaceScale(size: size, tiltDegrees: tiltDegrees, scale: scale) {
            drawChevron(
                points: [
                    CGPoint(x: center.x - 2.1, y: center.y + 2.4),
                    CGPoint(x: center.x - 0.1, y: center.y + 0.4),
                    CGPoint(x: center.x - 2.1, y: center.y - 1.6)
                ],
                width: 1.35
            )
            drawChevron(
                points: [
                    CGPoint(x: center.x + 2.1, y: center.y + 2.4),
                    CGPoint(x: center.x + 0.1, y: center.y + 0.4),
                    CGPoint(x: center.x + 2.1, y: center.y - 1.6)
                ],
                width: 1.35
            )
        }
    }

    private static func drawRelaxExpression(size: NSSize, tiltDegrees: CGFloat, scale: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        withClearFaceScale(size: size, tiltDegrees: tiltDegrees, scale: scale) {
            drawLine(
                from: CGPoint(x: center.x - 4.0, y: center.y + 1.8),
                to: CGPoint(x: center.x - 1.0, y: center.y + 2.55),
                width: 1.25
            )
            drawLine(
                from: CGPoint(x: center.x + 1.0, y: center.y + 2.55),
                to: CGPoint(x: center.x + 4.0, y: center.y + 1.8),
                width: 1.25
            )
            drawChevron(
                points: [
                    CGPoint(x: center.x - 1.75, y: center.y - 0.3),
                    CGPoint(x: center.x, y: center.y - 2.05),
                    CGPoint(x: center.x + 1.75, y: center.y - 0.3)
                ],
                width: 1.2
            )
        }
    }

    private static func drawEatingExpression(size: NSSize, tiltDegrees: CGFloat, scale: CGFloat, yOffset: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        withClearFaceScale(size: size, tiltDegrees: tiltDegrees, scale: scale) {
            for baseX in [center.x - 2.65, center.x + 2.65] {
                let rect = CGRect(
                    x: baseX - 1.95,
                    y: center.y + 0.45 + yOffset,
                    width: 3.9,
                    height: 1.35
                )
                NSBezierPath(roundedRect: rect, xRadius: 0.25, yRadius: 0.25).fill()
            }
        }
    }

    private static func drawSleepingExpression(size: NSSize, tiltDegrees: CGFloat, scale: CGFloat, progress: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let clampedProgress = max(0, min(1, progress))
        let eyeBob = CGFloat(sin(clampedProgress * .pi * 2)) * 0.38

        withDestinationOutFaceScale(size: size, tiltDegrees: tiltDegrees, scale: scale, alpha: 1) {
            let eyeBaseY = center.y - 2.1
            let leftRect = CGRect(x: center.x - 4.55, y: eyeBaseY + eyeBob, width: 3.75, height: 1.28)
            let rightRect = CGRect(x: center.x + 0.85, y: eyeBaseY + eyeBob, width: 3.75, height: 1.28)
            NSBezierPath(roundedRect: leftRect, xRadius: 0.24, yRadius: 0.24).fill()
            NSBezierPath(roundedRect: rightRect, xRadius: 0.24, yRadius: 0.24).fill()
        }

        let zAlpha = max(0.08, 0.95 * (1 - clampedProgress))
        let zRise = clampedProgress * 4.2
        withDestinationOutFaceScale(size: size, tiltDegrees: tiltDegrees, scale: scale, alpha: zAlpha) {
            let path = NSBezierPath()
            path.lineWidth = 1.35
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: CGPoint(x: center.x + 1.9, y: center.y + 3.55 + zRise))
            path.line(to: CGPoint(x: center.x + 5.25, y: center.y + 3.55 + zRise))
            path.line(to: CGPoint(x: center.x + 1.9, y: center.y + 1.25 + zRise))
            path.line(to: CGPoint(x: center.x + 5.25, y: center.y + 1.25 + zRise))
            path.stroke()
        }
    }

    private static func drawWakingExpression(size: NSSize, tiltDegrees: CGFloat, scale: CGFloat, progress: CGFloat, sleepProgress: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let clampedProgress = max(0, min(1, progress))
        let zProgress = max(0, min(1, clampedProgress / 0.32))
        let eyeProgress = max(0, min(1, (clampedProgress - 0.18) / 0.82))
        let easedEyeProgress = 0.5 - cos(eyeProgress * .pi) / 2

        let sleepingEyeBob = CGFloat(sin(sleepProgress * .pi * 2)) * 0.28 * (1 - easedEyeProgress)
        let eyeWidth = 3.75 + (1.75 - 3.75) * easedEyeProgress
        let eyeHeight = 1.28 + (4.9 - 1.28) * easedEyeProgress
        let eyeBaseY = (center.y - 2.1) + ((center.y + 0.55) - (center.y - 2.1)) * easedEyeProgress

        withDestinationOutFaceScale(size: size, tiltDegrees: tiltDegrees, scale: scale, alpha: 1) {
            for baseX in [center.x - 2.65, center.x + 2.65] {
                let rect = CGRect(
                    x: baseX - eyeWidth / 2,
                    y: eyeBaseY + sleepingEyeBob - eyeHeight / 2,
                    width: eyeWidth,
                    height: eyeHeight
                )
                NSBezierPath(roundedRect: rect, xRadius: max(0.24, eyeWidth / 2), yRadius: max(0.24, eyeWidth / 2)).fill()
            }
        }

        let zAlpha = 0.95 * (1 - zProgress)
        guard zAlpha > 0.02 else { return }

        let zRise = (sleepProgress * 4.2) + zProgress * 2.2
        withDestinationOutFaceScale(size: size, tiltDegrees: tiltDegrees, scale: scale, alpha: zAlpha) {
            let path = NSBezierPath()
            path.lineWidth = 1.35
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: CGPoint(x: center.x + 1.9, y: center.y + 3.55 + zRise))
            path.line(to: CGPoint(x: center.x + 5.25, y: center.y + 3.55 + zRise))
            path.line(to: CGPoint(x: center.x + 1.9, y: center.y + 1.25 + zRise))
            path.line(to: CGPoint(x: center.x + 5.25, y: center.y + 1.25 + zRise))
            path.stroke()
        }
    }

    private static func withClearFaceScale(size: NSSize, tiltDegrees: CGFloat, scale: CGFloat, draw: () -> Void) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: tiltDegrees)
        transform.scale(by: scale)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()

        NSGraphicsContext.current?.compositingOperation = .clear
        NSColor.clear.setStroke()
        NSColor.clear.setFill()
        draw()

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func withDestinationOutFaceScale(size: NSSize, tiltDegrees: CGFloat, scale: CGFloat, alpha: CGFloat, draw: () -> Void) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: tiltDegrees)
        transform.scale(by: scale)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()

        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSColor.white.withAlphaComponent(max(0, min(1, alpha))).setStroke()
        NSColor.white.withAlphaComponent(max(0, min(1, alpha))).setFill()
        draw()

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawLine(from start: CGPoint, to end: CGPoint, width: CGFloat) {
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .butt
        path.move(to: start)
        path.line(to: end)
        path.stroke()
    }

    private static func drawChevron(points: [CGPoint], width: CGFloat) {
        guard let first = points.first else { return }
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .butt
        path.lineJoinStyle = .miter
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }
        path.stroke()
    }
}

struct FlowerMark: View {
    let style: FlowerIconStyle
    let phase: KegelPhase
    let isAnimating: Bool

    @State private var blinkStartDate: Date?
    @State private var nextBlinkAt = Date().addingTimeInterval(0.8)
    @State private var remainingBlinkBursts = 0
    @State private var lookOffset = CGPoint.zero
    @State private var faceNow = Date()
    private let faceTimer = Timer.publish(every: 1.0 / 18.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let color = Color.white
            context.opacity = 0.95

            switch style {
            case .fourPetal, .sixPetal:
                if style == .fourPetal {
                    let side = min(size.width, size.height)
                    let petalSide = side * 0.54
                    let offset = side * 0.16
                    for petalCenter in [
                        CGPoint(x: center.x - offset, y: center.y - offset),
                        CGPoint(x: center.x + offset, y: center.y - offset),
                        CGPoint(x: center.x - offset, y: center.y + offset),
                        CGPoint(x: center.x + offset, y: center.y + offset)
                    ] {
                        context.fill(
                            Path(ellipseIn: CGRect(x: petalCenter.x - petalSide / 2, y: petalCenter.y - petalSide / 2, width: petalSide, height: petalSide)),
                            with: .color(color)
                        )
                    }
                } else {
                    let count = 6
                    let radius = min(size.width, size.height) * 0.22
                    let petal = CGSize(width: min(size.width, size.height) * 0.31, height: min(size.width, size.height) * 0.42)
                    for index in 0..<count {
                        let angle = (CGFloat(index) / CGFloat(count)) * .pi * 2
                        let petalCenter = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                        let rect = CGRect(x: petalCenter.x - petal.width / 2, y: petalCenter.y - petal.height / 2, width: petal.width, height: petal.height)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                    let core = min(size.width, size.height) * 0.24
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - core / 2, y: center.y - core / 2, width: core, height: core)),
                        with: .color(color)
                    )
                }
            case .ring:
                let rect = CGRect(x: size.width * 0.16, y: size.height * 0.16, width: size.width * 0.68, height: size.height * 0.68)
                var path = Path(ellipseIn: rect)
                path.addPath(Path(ellipseIn: rect.insetBy(dx: size.width * 0.16, dy: size.height * 0.16)))
                context.fill(path, with: .color(color), style: FillStyle(eoFill: true))
            }

            if isAnimating {
                drawLargeExpression(in: &context, size: size, phase: phase)
            } else {
                drawLargeNormalEyes(in: &context, size: size)
            }
        }
        .scaleEffect(isAnimating ? (phase == .contract ? 0.54 : 1.0) : 1)
        .animation(phase == .contract ? .easeInOut(duration: 1.0) : .easeOut(duration: 0.45), value: phase)
        .shadow(color: .white.opacity(0.32), radius: isAnimating ? 12 : 2)
        .onReceive(faceTimer) { now in
            advanceLargeFace(now: now)
        }
    }

    private func advanceLargeFace(now: Date) {
        faceNow = now

        guard !isAnimating else {
            lookOffset = .zero
            return
        }

        if now >= nextBlinkAt {
            blinkStartDate = now
            if remainingBlinkBursts > 0 {
                remainingBlinkBursts -= 1
                nextBlinkAt = now.addingTimeInterval(TimeInterval.random(in: 0.16...0.28))
            } else {
                remainingBlinkBursts = Double.random(in: 0...1) > 0.72 ? 1 : 0
                nextBlinkAt = now.addingTimeInterval(TimeInterval.random(in: 1.4...4.6))
            }
        }

        lookOffset.x *= 0.65
        lookOffset.y *= 0.65
    }

    private var largeBlinkAmount: CGFloat {
        guard let blinkStartDate else { return 0 }
        let elapsed = faceNow.timeIntervalSince(blinkStartDate)
        let duration: TimeInterval = 0.32
        guard elapsed < duration else {
            DispatchQueue.main.async {
                self.blinkStartDate = nil
            }
            return 0
        }

        let progress = max(0, min(1, elapsed / duration))
        return CGFloat(sin(progress * .pi))
    }

    private func drawLargeNormalEyes(in context: inout GraphicsContext, size: CGSize) {
        let side = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let blink = max(0, min(1, largeBlinkAmount))
        let eyeWidth = side * (0.09 + 0.12 * blink)
        let eyeHeight = max(side * 0.012, side * 0.29 * (1 - blink))
        let faceColor = Color.black.opacity(1.0)

        for baseX in [center.x - side * 0.16, center.x + side * 0.16] {
            let rect = CGRect(
                x: baseX + lookOffset.x - eyeWidth / 2,
                y: center.y + lookOffset.y - eyeHeight / 2,
                width: eyeWidth,
                height: eyeHeight
            )
            context.fill(Path(roundedRect: rect, cornerRadius: eyeWidth * 0.18), with: .color(faceColor))
        }
    }

    private func drawLargeExpression(in context: inout GraphicsContext, size: CGSize, phase: KegelPhase) {
        let side = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let faceColor = Color.black.opacity(0.9)

        if phase == .contract {
            drawLargeLine(
                in: &context,
                points: [
                    CGPoint(x: center.x - side * 0.15, y: center.y - side * 0.15),
                    CGPoint(x: center.x - side * 0.02, y: center.y),
                    CGPoint(x: center.x - side * 0.15, y: center.y + side * 0.15)
                ],
                width: side * 0.055,
                color: faceColor
            )
            drawLargeLine(
                in: &context,
                points: [
                    CGPoint(x: center.x + side * 0.15, y: center.y - side * 0.15),
                    CGPoint(x: center.x + side * 0.02, y: center.y),
                    CGPoint(x: center.x + side * 0.15, y: center.y + side * 0.15)
                ],
                width: side * 0.055,
                color: faceColor
            )
        } else {
            drawLargeLine(
                in: &context,
                points: [
                    CGPoint(x: center.x - side * 0.23, y: center.y - side * 0.09),
                    CGPoint(x: center.x - side * 0.06, y: center.y - side * 0.14)
                ],
                width: side * 0.05,
                color: faceColor
            )
            drawLargeLine(
                in: &context,
                points: [
                    CGPoint(x: center.x + side * 0.06, y: center.y - side * 0.14),
                    CGPoint(x: center.x + side * 0.23, y: center.y - side * 0.09)
                ],
                width: side * 0.05,
                color: faceColor
            )
            drawLargeLine(
                in: &context,
                points: [
                    CGPoint(x: center.x - side * 0.11, y: center.y + side * 0.08),
                    CGPoint(x: center.x, y: center.y + side * 0.20),
                    CGPoint(x: center.x + side * 0.11, y: center.y + side * 0.08)
                ],
                width: side * 0.05,
                color: faceColor
            )
        }
    }

    private func drawLargeLine(in context: inout GraphicsContext, points: [CGPoint], width: CGFloat, color: Color) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .butt, lineJoin: .miter))
    }
}
