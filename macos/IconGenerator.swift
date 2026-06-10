import AppKit

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

guard CommandLine.arguments.count == 2 else {
    exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let background = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 206, yRadius: 206)
NSColor(hex: 0xF4F8EC).setFill()
background.fill()

let panel = NSBezierPath(roundedRect: NSRect(x: 145, y: 215, width: 734, height: 594), xRadius: 74, yRadius: 74)
NSColor(hex: 0x202819).setFill()
panel.fill()

let midline = NSBezierPath()
midline.move(to: NSPoint(x: 200, y: 515))
midline.line(to: NSPoint(x: 824, y: 515))
midline.lineWidth = 6
NSColor(hex: 0x557252).setStroke()
midline.stroke()

let upload = NSBezierPath()
upload.move(to: NSPoint(x: 200, y: 505))
upload.line(to: NSPoint(x: 295, y: 505))
upload.line(to: NSPoint(x: 345, y: 430))
upload.line(to: NSPoint(x: 382, y: 505))
upload.line(to: NSPoint(x: 492, y: 505))
upload.line(to: NSPoint(x: 528, y: 397))
upload.line(to: NSPoint(x: 568, y: 505))
upload.line(to: NSPoint(x: 824, y: 505))
upload.lineWidth = 12
NSColor(hex: 0xB8504C).setStroke()
upload.stroke()

let download = NSBezierPath()
download.move(to: NSPoint(x: 200, y: 525))
download.line(to: NSPoint(x: 270, y: 525))
download.line(to: NSPoint(x: 306, y: 578))
download.line(to: NSPoint(x: 342, y: 525))
download.line(to: NSPoint(x: 617, y: 525))
download.line(to: NSPoint(x: 660, y: 643))
download.line(to: NSPoint(x: 700, y: 525))
download.line(to: NSPoint(x: 824, y: 525))
download.lineWidth = 12
NSColor(hex: 0x00A5FF).setStroke()
download.stroke()

let activity = NSBezierPath(ovalIn: NSRect(x: 754, y: 283, width: 62, height: 62))
NSColor(hex: 0x33E982).setFill()
activity.fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let png = representation.representation(using: .png, properties: [:]) else {
    exit(1)
}
try png.write(to: output)
