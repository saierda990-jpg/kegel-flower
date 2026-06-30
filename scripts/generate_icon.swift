import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/AppIcon.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let iconsetURL = outputURL.deletingPathExtension().appendingPathExtension("iconset")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in entries {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    NSGraphicsContext.current?.imageInterpolation = .high

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = CGFloat(size) * 0.225
    NSColor.black.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

    drawFlower(in: rect.insetBy(dx: CGFloat(size) * 0.16, dy: CGFloat(size) * 0.16))

    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(name)")
    }

    try pngData.write(to: iconsetURL.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fatalError("iconutil failed")
}

try? fileManager.removeItem(at: iconsetURL)

func drawFlower(in rect: CGRect) {
    NSColor.white.setFill()

    let center = CGPoint(x: rect.midX, y: rect.midY)
    let side = min(rect.width, rect.height)
    let offset = side * 0.16
    let petalSize = CGSize(width: side * 0.56, height: side * 0.56)

    for petalCenter in [
        CGPoint(x: center.x - offset, y: center.y + offset),
        CGPoint(x: center.x + offset, y: center.y + offset),
        CGPoint(x: center.x - offset, y: center.y - offset),
        CGPoint(x: center.x + offset, y: center.y - offset)
    ] {
        let petalRect = CGRect(
            x: petalCenter.x - petalSize.width / 2,
            y: petalCenter.y - petalSize.height / 2,
            width: petalSize.width,
            height: petalSize.height
        )
        NSBezierPath(ovalIn: petalRect).fill()
    }

    NSColor.black.setFill()
    let eyeWidth = side * 0.09
    let eyeHeight = side * 0.27
    let eyeY = center.y - eyeHeight * 0.38
    for eyeX in [center.x - side * 0.145, center.x + side * 0.145] {
        NSBezierPath(
            roundedRect: CGRect(
                x: eyeX - eyeWidth / 2,
                y: eyeY,
                width: eyeWidth,
                height: eyeHeight
            ),
            xRadius: eyeWidth * 0.22,
            yRadius: eyeWidth * 0.22
        ).fill()
    }
}
