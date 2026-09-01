import AppKit
import CoreText

private extension NSColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}

private func drawText(
    _ value: String,
    at point: NSPoint,
    font: NSFont,
    color: NSColor,
    tracking: CGFloat = 0
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: tracking
    ]
    value.draw(at: point, withAttributes: attributes)
}

private func drawPulseMark(at origin: NSPoint, color: NSColor) {
    let mark = NSBezierPath()
    mark.move(to: NSPoint(x: origin.x, y: origin.y + 14))
    mark.line(to: NSPoint(x: origin.x + 8, y: origin.y + 14))
    mark.line(to: NSPoint(x: origin.x + 12, y: origin.y + 24))
    mark.line(to: NSPoint(x: origin.x + 17, y: origin.y + 3))
    mark.line(to: NSPoint(x: origin.x + 22, y: origin.y + 18))
    mark.line(to: NSPoint(x: origin.x + 28, y: origin.y + 14))
    mark.line(to: NSPoint(x: origin.x + 38, y: origin.y + 14))
    mark.lineWidth = 2.3
    mark.lineCapStyle = .round
    mark.lineJoinStyle = .round
    color.setStroke()
    mark.stroke()
}

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: dmg-background <output.png>\n", stderr)
    exit(1)
}

if CommandLine.arguments.count > 2 {
    let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    for name in ["Romie-Regular", "Roobert-Regular", "Roobert-Bold"] {
        let url = directory.appendingPathComponent(name + ".otf")
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

let outputPath = CommandLine.arguments[1]

let canvas = NSSize(width: 720, height: 430)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas.width),
    pixelsHigh: Int(canvas.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Unable to create background bitmap\n", stderr)
    exit(1)
}
bitmap.size = canvas
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

let frame = NSRect(origin: .zero, size: canvas)
let ink = NSColor(hex: 0x202819)
let strong = NSColor(hex: 0x557252)
let cta = NSColor(hex: 0x33E982)
let light = NSColor(hex: 0xEBFFEB)
let surface = NSColor(hex: 0xF4F8EC)
let line = NSColor(hex: 0xCDD5BC)

NSGradient(colors: [light, NSColor(hex: 0xE9F3E5), surface])?
    .draw(in: frame, angle: -22)

let glow = NSBezierPath(ovalIn: NSRect(x: 492, y: 288, width: 300, height: 250))
cta.withAlphaComponent(0.09).setFill()
glow.fill()

drawPulseMark(at: NSPoint(x: 43, y: 357), color: strong)

drawText(
    "Szlauch",
    at: NSPoint(x: 94, y: 350),
    font: NSFont(name: "Romie-Regular", size: 36) ?? .systemFont(ofSize: 30, weight: .semibold),
    color: ink
)
drawText(
    "Przeciągnij aplikację do folderu Applications.",
    at: NSPoint(x: 43, y: 304),
    font: NSFont(name: "Roobert-Regular", size: 14) ?? .systemFont(ofSize: 13.5, weight: .medium),
    color: strong
)

let trayRect = NSRect(x: 32, y: 60, width: 656, height: 170)
let tray = NSBezierPath(roundedRect: trayRect, xRadius: 22, yRadius: 22)
surface.withAlphaComponent(0.72).setFill()
tray.fill()
line.withAlphaComponent(0.80).setStroke()
tray.lineWidth = 1
tray.stroke()

drawText(
    "SZLAUCH",
    at: NSPoint(x: 111, y: 205),
    font: .systemFont(ofSize: 10.5, weight: .bold),
    color: strong,
    tracking: 1.0
)
drawText(
    "APPLICATIONS",
    at: NSPoint(x: 492, y: 205),
    font: .systemFont(ofSize: 10.5, weight: .bold),
    color: strong,
    tracking: 1.0
)

let route = NSBezierPath()
route.move(to: NSPoint(x: 274, y: 143))
route.line(to: NSPoint(x: 435, y: 143))
cta.withAlphaComponent(0.46).setStroke()
route.lineWidth = 2.5
route.stroke()

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 435, y: 143))
arrow.line(to: NSPoint(x: 423, y: 151))
arrow.move(to: NSPoint(x: 435, y: 143))
arrow.line(to: NSPoint(x: 423, y: 135))
arrow.lineWidth = 2.5
arrow.stroke()

drawText(
    "macOS 13+  •  Apple Silicon + Intel",
    at: NSPoint(x: 42, y: 42),
    font: .systemFont(ofSize: 11, weight: .medium),
    color: strong.withAlphaComponent(0.78)
)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode background image\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
} catch {
    fputs("Unable to write background image: \(error)\n", stderr)
    exit(1)
}
