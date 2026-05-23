import AppKit

struct SizeVariant {
    let name: String
    let pixels: Int
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/assets", isDirectory: true)
let iconset = output.appendingPathComponent("AppIcon.iconset", isDirectory: true)

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "GenerateAssets", code: 1)
    }

    try png.write(to: url)
}

func image(size: Int, scale: CGFloat, draw: (CGRect) -> Void) -> NSImage {
    let pointSize = CGFloat(size) / scale
    let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(CGRect(x: 0, y: 0, width: pointSize, height: pointSize))
    image.unlockFocus()

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return image
    }

    rep.size = NSSize(width: pointSize, height: pointSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGRect(x: 0, y: 0, width: pointSize, height: pointSize))
    NSGraphicsContext.restoreGraphicsState()

    let rendered = NSImage(size: NSSize(width: pointSize, height: pointSize))
    rendered.addRepresentation(rep)
    return rendered
}

func strokePath(_ path: NSBezierPath, color: NSColor, width: CGFloat, cap: NSBezierPath.LineCapStyle = .round, join: NSBezierPath.LineJoinStyle = .round) {
    path.lineWidth = width
    path.lineCapStyle = cap
    path.lineJoinStyle = join
    color.setStroke()
    path.stroke()
}

func fillPath(_ path: NSBezierPath, color: NSColor) {
    color.setFill()
    path.fill()
}

func drawMark(in rect: CGRect, foreground: NSColor, background: NSColor?, lineScale: CGFloat, insetScale: CGFloat = 0.21) {
    if let background {
        let radius = rect.width * 0.22
        fillPath(NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius), color: background)
    }

    let inset = rect.width * insetScale
    let circle = rect.insetBy(dx: inset, dy: inset)
    let stroke = rect.width * lineScale
    strokePath(NSBezierPath(ovalIn: circle), color: foreground, width: stroke)

    let wave = NSBezierPath()
    wave.move(to: CGPoint(x: circle.minX + stroke * 0.55, y: circle.midY - rect.width * 0.04))
    wave.curve(
        to: CGPoint(x: circle.midX - rect.width * 0.19, y: circle.midY - rect.width * 0.07),
        controlPoint1: CGPoint(x: circle.minX + rect.width * 0.08, y: circle.midY + rect.width * 0.01),
        controlPoint2: CGPoint(x: circle.midX - rect.width * 0.25, y: circle.midY - rect.width * 0.15)
    )
    wave.curve(
        to: CGPoint(x: circle.midX, y: circle.midY + rect.width * 0.22),
        controlPoint1: CGPoint(x: circle.midX - rect.width * 0.10, y: circle.midY - rect.width * 0.01),
        controlPoint2: CGPoint(x: circle.midX - rect.width * 0.07, y: circle.midY + rect.width * 0.22)
    )
    wave.curve(
        to: CGPoint(x: circle.midX + rect.width * 0.19, y: circle.midY - rect.width * 0.07),
        controlPoint1: CGPoint(x: circle.midX + rect.width * 0.07, y: circle.midY + rect.width * 0.22),
        controlPoint2: CGPoint(x: circle.midX + rect.width * 0.10, y: circle.midY - rect.width * 0.01)
    )
    wave.curve(
        to: CGPoint(x: circle.maxX - stroke * 0.55, y: circle.midY - rect.width * 0.04),
        controlPoint1: CGPoint(x: circle.midX + rect.width * 0.20, y: circle.midY - rect.width * 0.14),
        controlPoint2: CGPoint(x: circle.maxX - rect.width * 0.08, y: circle.midY + rect.width * 0.02)
    )
    strokePath(wave, color: foreground, width: stroke)
}

let iconSizes = [
    SizeVariant(name: "icon_16x16.png", pixels: 16),
    SizeVariant(name: "icon_16x16@2x.png", pixels: 32),
    SizeVariant(name: "icon_32x32.png", pixels: 32),
    SizeVariant(name: "icon_32x32@2x.png", pixels: 64),
    SizeVariant(name: "icon_128x128.png", pixels: 128),
    SizeVariant(name: "icon_128x128@2x.png", pixels: 256),
    SizeVariant(name: "icon_256x256.png", pixels: 256),
    SizeVariant(name: "icon_256x256@2x.png", pixels: 512),
    SizeVariant(name: "icon_512x512.png", pixels: 512),
    SizeVariant(name: "icon_512x512@2x.png", pixels: 1024),
]

for variant in iconSizes {
    let rendered = image(size: variant.pixels, scale: 1) { rect in
        NSColor.clear.setFill()
        rect.fill()
        drawMark(
            in: rect,
            foreground: .white,
            background: NSColor(calibratedWhite: 0.015, alpha: 1),
            lineScale: 0.044
        )
    }
    try savePNG(rendered, to: iconset.appendingPathComponent(variant.name))
}

let template = image(size: 44, scale: 2) { rect in
    NSColor.clear.setFill()
    rect.fill()
    drawMark(in: rect, foreground: .black, background: nil, lineScale: 0.06, insetScale: 0.12)
}
try savePNG(template, to: output.appendingPathComponent("MenuBarIconTemplate.png"))
