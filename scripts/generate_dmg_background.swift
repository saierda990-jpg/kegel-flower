import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/dmg-background.png"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let width: CGFloat = 600
let height: CGFloat = 310
let image = NSImage(size: NSSize(width: width, height: height))

image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high

drawPaper()
drawRadialBurst(from: CGPoint(x: 145, y: 198))
drawHalftoneField(origin: CGPoint(x: 360, y: 16), columns: 28, rows: 14, spacing: 7, maxRadius: 2.1)
drawHalftoneField(origin: CGPoint(x: 22, y: 228), columns: 18, rows: 9, spacing: 6, maxRadius: 1.6)
drawRecognizableFlower()
drawImpactMarks()
drawSafeInstallationHalos()
drawInstallArrow(from: CGPoint(x: 252, y: 170), to: CGPoint(x: 365, y: 170))
drawInstallText()
drawBorderTexture()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fatalError("Could not render DMG background")
}

try png.write(to: outputURL)

func drawPaper() {
    NSColor(white: 0.94, alpha: 1).setFill()
    NSBezierPath(rect: CGRect(x: 0, y: 0, width: width, height: height)).fill()

    for y in stride(from: CGFloat(0), through: height, by: 4) {
        NSColor(white: 0.0, alpha: 0.025).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 0.5
        path.move(to: CGPoint(x: 0, y: y))
        path.line(to: CGPoint(x: width, y: y + 1))
        path.stroke()
    }
}

func drawRadialBurst(from focus: CGPoint) {
    let endpoints: [CGPoint] = [
        CGPoint(x: 0, y: 18), CGPoint(x: 0, y: 72), CGPoint(x: 0, y: 298),
        CGPoint(x: 58, y: 310), CGPoint(x: 122, y: 310), CGPoint(x: 220, y: 310),
        CGPoint(x: 318, y: 310), CGPoint(x: 438, y: 310), CGPoint(x: 594, y: 300),
        CGPoint(x: 600, y: 246), CGPoint(x: 600, y: 205), CGPoint(x: 600, y: 70),
        CGPoint(x: 506, y: 0), CGPoint(x: 404, y: 0), CGPoint(x: 286, y: 0),
        CGPoint(x: 188, y: 0), CGPoint(x: 84, y: 0)
    ]

    for (index, end) in endpoints.enumerated() {
        let path = NSBezierPath()
        path.lineWidth = index % 3 == 0 ? 2.4 : 1.1
        NSColor.black.withAlphaComponent(index % 3 == 0 ? 0.36 : 0.22).setStroke()
        path.move(to: focus)
        path.line(to: end)
        path.stroke()
    }

    for i in 0..<42 {
        let angle = CGFloat(i) / 42 * CGFloat.pi * 2
        let inner = CGPoint(x: focus.x + cos(angle) * 78, y: focus.y + sin(angle) * 42)
        let outer = CGPoint(x: focus.x + cos(angle) * 560, y: focus.y + sin(angle) * 330)
        let path = NSBezierPath()
        path.lineWidth = i % 5 == 0 ? 1.5 : 0.65
        NSColor.black.withAlphaComponent(i % 5 == 0 ? 0.22 : 0.13).setStroke()
        path.move(to: inner)
        path.line(to: outer)
        path.stroke()
    }
}

func drawHalftoneField(origin: CGPoint, columns: Int, rows: Int, spacing: CGFloat, maxRadius: CGFloat) {
    for row in 0..<rows {
        for column in 0..<columns {
            let distance = CGFloat(row + column) / CGFloat(rows + columns)
            let radius = max(0.35, maxRadius * (1 - distance * 0.75))
            let x = origin.x + CGFloat(column) * spacing + (row % 2 == 0 ? 0 : spacing / 2)
            let y = origin.y + CGFloat(row) * spacing
            NSColor.black.withAlphaComponent(0.16).setFill()
            NSBezierPath(ovalIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)).fill()
        }
    }
}

func drawRecognizableFlower() {
    let center = CGPoint(x: 154, y: 198)

    drawPetal(center: CGPoint(x: center.x - 46, y: center.y + 42), size: CGSize(width: 118, height: 112), rotation: -12, lineWidth: 6.5)
    drawPetal(center: CGPoint(x: center.x + 46, y: center.y + 42), size: CGSize(width: 112, height: 108), rotation: 13, lineWidth: 6.2)
    drawPetal(center: CGPoint(x: center.x - 46, y: center.y - 42), size: CGSize(width: 118, height: 112), rotation: 12, lineWidth: 6.5)
    drawPetal(center: CGPoint(x: center.x + 46, y: center.y - 42), size: CGSize(width: 112, height: 108), rotation: -13, lineWidth: 6.2)

    drawFlowerCenterGlow(center: center)
    drawPetalDepthShadows(center: center)
    drawPuckeredFace(center: CGPoint(x: center.x + 2, y: center.y - 4))
    drawFacialTension(center: CGPoint(x: center.x + 2, y: center.y - 4))
    drawFlowerStressLines(around: center)
    drawMotionSmears(from: center)
}

func drawPetal(center: CGPoint, size: CGSize, rotation: CGFloat, lineWidth: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: rotation)
    transform.translateX(by: -center.x, yBy: -center.y)
    transform.concat()

    let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    let shadow = NSBezierPath(ovalIn: rect.offsetBy(dx: 6, dy: -6))
    NSColor.black.withAlphaComponent(0.16).setFill()
    shadow.fill()

    let petal = NSBezierPath(ovalIn: rect)
    NSColor.white.setFill()
    petal.fill()
    NSColor.black.setStroke()
    petal.lineWidth = lineWidth
    petal.stroke()

    let hatch = NSBezierPath()
    hatch.lineWidth = 0.55
    NSColor.black.withAlphaComponent(0.16).setStroke()
    for x in stride(from: rect.minX + 20, through: rect.maxX - 14, by: 16) {
        hatch.move(to: CGPoint(x: x, y: rect.minY + 12))
        hatch.line(to: CGPoint(x: x + 22, y: rect.maxY - 12))
    }
    hatch.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

func drawFlowerCenterGlow(center: CGPoint) {
    let oval = NSBezierPath(ovalIn: CGRect(x: center.x - 34, y: center.y - 30, width: 72, height: 64))
    NSColor.white.setFill()
    oval.fill()
    NSColor.black.withAlphaComponent(0.22).setStroke()
    oval.lineWidth = 2
    oval.stroke()
}

func drawPetalDepthShadows(center: CGPoint) {
    let shadowRects = [
        CGRect(x: center.x - 100, y: center.y + 4, width: 52, height: 78),
        CGRect(x: center.x + 40, y: center.y + 12, width: 48, height: 72),
        CGRect(x: center.x - 94, y: center.y - 82, width: 56, height: 72),
        CGRect(x: center.x + 38, y: center.y - 76, width: 50, height: 70)
    ]

    for (index, rect) in shadowRects.enumerated() {
        NSGraphicsContext.saveGraphicsState()
        let clip = NSBezierPath(ovalIn: rect.insetBy(dx: -24, dy: -20))
        clip.addClip()
        NSColor.black.withAlphaComponent(index % 2 == 0 ? 0.12 : 0.09).setFill()
        NSBezierPath(ovalIn: rect).fill()
        drawLocalHalftone(in: rect.insetBy(dx: -6, dy: -4), radius: index % 2 == 0 ? 1.3 : 1.0)
        NSGraphicsContext.restoreGraphicsState()
    }
}

func drawLocalHalftone(in rect: CGRect, radius: CGFloat) {
    for y in stride(from: rect.minY, through: rect.maxY, by: 7) {
        for x in stride(from: rect.minX, through: rect.maxX, by: 7) {
            NSColor.black.withAlphaComponent(0.18).setFill()
            NSBezierPath(ovalIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)).fill()
        }
    }
}

func drawPuckeredFace(center: CGPoint) {
    NSColor.black.setFill()
    for (index, x) in [center.x - 28, center.x + 28].enumerated() {
        let rect = CGRect(x: x - 8, y: center.y + 19, width: 16, height: 45)
        let eye = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        eye.fill()

        NSColor.white.withAlphaComponent(0.72).setFill()
        let shine = CGRect(x: rect.minX + 3, y: rect.maxY - 13, width: 3, height: 8)
        NSBezierPath(roundedRect: shine, xRadius: 1.5, yRadius: 1.5).fill()
        NSColor.black.setFill()

        let tremble = NSBezierPath()
        tremble.lineWidth = 1.4
        tremble.lineCapStyle = .round
        NSColor.black.setStroke()
        let side: CGFloat = index == 0 ? -1 : 1
        for n in 0..<3 {
            let y = rect.minY + CGFloat(n) * 13 + 4
            tremble.move(to: CGPoint(x: rect.midX + side * 12, y: y))
            tremble.line(to: CGPoint(x: rect.midX + side * 20, y: y + 5))
        }
        tremble.stroke()
    }

    let outerRect = CGRect(x: center.x - 23, y: center.y - 24, width: 52, height: 44)
    let outer = NSBezierPath(ovalIn: outerRect)
    NSColor.black.setFill()
    outer.fill()

    NSColor.white.withAlphaComponent(0.25).setFill()
    NSBezierPath(ovalIn: outerRect.insetBy(dx: 4, dy: 5).offsetBy(dx: -4, dy: 5)).fill()

    let inner = NSBezierPath(ovalIn: CGRect(x: center.x - 8, y: center.y - 8, width: 20, height: 15))
    NSColor.white.setFill()
    inner.fill()

    let wrinkle = NSBezierPath()
    wrinkle.lineWidth = 2.2
    wrinkle.lineCapStyle = .round
    NSColor.black.setStroke()
    for angle in stride(from: CGFloat(0), to: CGFloat.pi * 2, by: CGFloat.pi / 5) {
        let start = CGPoint(x: center.x + cos(angle) * 30, y: center.y - 1 + sin(angle) * 24)
        let end = CGPoint(x: center.x + cos(angle) * 43, y: center.y - 1 + sin(angle) * 34)
        wrinkle.move(to: start)
        wrinkle.line(to: end)
    }
    wrinkle.stroke()
}

func drawFacialTension(center: CGPoint) {
    NSColor.black.setStroke()
    let curves: [(CGPoint, CGPoint, CGPoint)] = [
        (CGPoint(x: center.x - 58, y: center.y + 18), CGPoint(x: center.x - 42, y: center.y + 8), CGPoint(x: center.x - 30, y: center.y - 2)),
        (CGPoint(x: center.x + 62, y: center.y + 18), CGPoint(x: center.x + 46, y: center.y + 8), CGPoint(x: center.x + 34, y: center.y - 2)),
        (CGPoint(x: center.x - 34, y: center.y - 42), CGPoint(x: center.x - 14, y: center.y - 32), CGPoint(x: center.x - 4, y: center.y - 22)),
        (CGPoint(x: center.x + 40, y: center.y - 42), CGPoint(x: center.x + 20, y: center.y - 32), CGPoint(x: center.x + 8, y: center.y - 22))
    ]

    for (start, control, end) in curves {
        let path = NSBezierPath()
        path.lineWidth = 2
        path.lineCapStyle = .round
        path.move(to: start)
        path.curve(to: end, controlPoint1: control, controlPoint2: control)
        path.stroke()
    }

    drawTinySweatDrop(at: CGPoint(x: center.x + 70, y: center.y + 65), rotation: -18)
    drawTinySweatDrop(at: CGPoint(x: center.x - 76, y: center.y + 58), rotation: 24)
}

func drawTinySweatDrop(at point: CGPoint, rotation: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: point.x, yBy: point.y)
    transform.rotate(byDegrees: rotation)
    transform.translateX(by: -point.x, yBy: -point.y)
    transform.concat()

    let path = NSBezierPath()
    path.move(to: CGPoint(x: point.x, y: point.y + 10))
    path.curve(to: CGPoint(x: point.x - 7, y: point.y - 5), controlPoint1: CGPoint(x: point.x - 8, y: point.y + 4), controlPoint2: CGPoint(x: point.x - 9, y: point.y - 2))
    path.curve(to: CGPoint(x: point.x + 7, y: point.y - 5), controlPoint1: CGPoint(x: point.x - 4, y: point.y - 11), controlPoint2: CGPoint(x: point.x + 4, y: point.y - 11))
    path.curve(to: CGPoint(x: point.x, y: point.y + 10), controlPoint1: CGPoint(x: point.x + 9, y: point.y - 2), controlPoint2: CGPoint(x: point.x + 8, y: point.y + 4))
    path.close()
    NSColor.white.setFill()
    path.fill()
    NSColor.black.setStroke()
    path.lineWidth = 2
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

func drawFlowerStressLines(around center: CGPoint) {
    NSColor.black.setStroke()
    for i in 0..<16 {
        let angle = CGFloat(i) / 16 * CGFloat.pi * 2
        let start = CGPoint(x: center.x + cos(angle) * 112, y: center.y + sin(angle) * 80)
        let end = CGPoint(x: center.x + cos(angle) * 142, y: center.y + sin(angle) * 102)
        let path = NSBezierPath()
        path.lineWidth = i % 2 == 0 ? 3 : 1.3
        path.lineCapStyle = .round
        path.move(to: start)
        path.line(to: end)
        path.stroke()
    }
}

func drawMotionSmears(from center: CGPoint) {
    NSColor.black.withAlphaComponent(0.34).setStroke()
    for offset in stride(from: CGFloat(-44), through: CGFloat(54), by: 18) {
        let path = NSBezierPath()
        path.lineWidth = 4
        path.lineCapStyle = .round
        path.move(to: CGPoint(x: center.x + 116, y: center.y + offset))
        path.line(to: CGPoint(x: center.x + 250, y: center.y + offset + 16))
        path.stroke()
    }

    NSColor.white.withAlphaComponent(0.72).setStroke()
    for offset in stride(from: CGFloat(-35), through: CGFloat(45), by: 24) {
        let path = NSBezierPath()
        path.lineWidth = 2
        path.lineCapStyle = .round
        path.move(to: CGPoint(x: center.x + 122, y: center.y + offset))
        path.line(to: CGPoint(x: center.x + 226, y: center.y + offset + 13))
        path.stroke()
    }
}

func drawImpactMarks() {
    drawMangaText("ギュッ!!", at: CGPoint(x: 286, y: 230), size: 36, rotation: -9)
    drawMangaText("ドン", at: CGPoint(x: 428, y: 225), size: 28, rotation: 8)
    drawMangaText("!!", at: CGPoint(x: 62, y: 55), size: 40, rotation: 13)
}

func drawMangaText(_ string: String, at point: CGPoint, size: CGFloat, rotation: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: point.x, yBy: point.y)
    transform.rotate(byDegrees: rotation)
    transform.translateX(by: -point.x, yBy: -point.y)
    transform.concat()

    let font = NSFont(name: "Hiragino Sans W8", size: size) ?? .boldSystemFont(ofSize: size)
    let rect = CGRect(x: point.x - 72, y: point.y - 24, width: 160, height: 54)
    let strokeAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .strokeColor: NSColor.black,
        .strokeWidth: -7
    ]
    string.draw(in: rect, withAttributes: strokeAttributes)
    NSGraphicsContext.restoreGraphicsState()
}

func drawSafeInstallationHalos() {
    for rect in [
        CGRect(x: 86, y: 94, width: 168, height: 116),
        CGRect(x: 380, y: 94, width: 152, height: 116)
    ] {
        let path = NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22)
        NSColor.white.withAlphaComponent(0.72).setFill()
        path.fill()
        NSColor.black.withAlphaComponent(0.10).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

func drawInstallArrow(from start: CGPoint, to end: CGPoint) {
    let outline = NSBezierPath()
    outline.lineWidth = 10
    outline.lineCapStyle = .round
    outline.move(to: start)
    outline.line(to: CGPoint(x: end.x - 22, y: end.y))
    NSColor.black.setStroke()
    outline.stroke()

    let inner = NSBezierPath()
    inner.lineWidth = 5
    inner.lineCapStyle = .round
    inner.move(to: start)
    inner.line(to: CGPoint(x: end.x - 22, y: end.y))
    NSColor.white.setStroke()
    inner.stroke()

    let head = NSBezierPath()
    head.move(to: end)
    head.line(to: CGPoint(x: end.x - 30, y: end.y + 19))
    head.line(to: CGPoint(x: end.x - 30, y: end.y - 19))
    head.close()
    NSColor.black.setFill()
    head.fill()

    let innerHead = NSBezierPath()
    innerHead.move(to: CGPoint(x: end.x - 5, y: end.y))
    innerHead.line(to: CGPoint(x: end.x - 27, y: end.y + 13))
    innerHead.line(to: CGPoint(x: end.x - 27, y: end.y - 13))
    innerHead.close()
    NSColor.white.setFill()
    innerHead.fill()
}

func drawInstallText() {
    let rect = CGRect(x: 188, y: 116, width: 224, height: 24)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let font = NSFont.systemFont(ofSize: 12, weight: .bold)

    "拖到 Applications 安装".draw(
        in: rect.offsetBy(dx: 1.5, dy: -1.5),
        withAttributes: [.font: font, .foregroundColor: NSColor.black.withAlphaComponent(0.55), .paragraphStyle: paragraph]
    )
    "拖到 Applications 安装".draw(
        in: rect,
        withAttributes: [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraph]
    )
}

func drawBorderTexture() {
    NSColor.black.withAlphaComponent(0.55).setStroke()
    let border = NSBezierPath(rect: CGRect(x: 5, y: 5, width: width - 10, height: height - 10))
    border.lineWidth = 2.2
    border.stroke()

    NSColor.black.withAlphaComponent(0.14).setStroke()
    for x in stride(from: CGFloat(0), through: width, by: 18) {
        let path = NSBezierPath()
        path.lineWidth = 0.8
        path.move(to: CGPoint(x: x, y: 0))
        path.line(to: CGPoint(x: x + 38, y: height))
        path.stroke()
    }
}
