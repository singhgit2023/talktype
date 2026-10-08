import AppKit
import Foundation

let size: CGFloat = 1024
let canvas = NSImage(size: NSSize(width: size, height: size))
canvas.lockFocus()

let shell = NSBezierPath(roundedRect: NSRect(x: 34, y: 34, width: 956, height: 956), xRadius: 238, yRadius: 238)
NSGraphicsContext.saveGraphicsState()
let shellShadow = NSShadow()
shellShadow.shadowColor = NSColor(calibratedRed: 0.26, green: 0.29, blue: 0.49, alpha: 0.18)
shellShadow.shadowBlurRadius = 30
shellShadow.shadowOffset = NSSize(width: 0, height: -12)
shellShadow.set()
NSGradient(starting: NSColor(calibratedRed: 0.92, green: 0.93, blue: 1, alpha: 1),
           ending: NSColor(calibratedRed: 1, green: 0.94, blue: 0.92, alpha: 1))?.draw(in: shell, angle: -45)
NSGraphicsContext.restoreGraphicsState()

let body = NSBezierPath(roundedRect: NSRect(x: 143, y: 145, width: 738, height: 738), xRadius: 220, yRadius: 220)
NSGraphicsContext.saveGraphicsState()
let bodyShadow = NSShadow()
bodyShadow.shadowColor = NSColor(calibratedRed: 0.33, green: 0.31, blue: 0.46, alpha: 0.18)
bodyShadow.shadowBlurRadius = 40
bodyShadow.shadowOffset = NSSize(width: 0, height: -18)
bodyShadow.set()
NSGradient(starting: .white,
           ending: NSColor(calibratedRed: 1, green: 0.965, blue: 0.95, alpha: 1))?.draw(in: body, angle: -75)
NSGraphicsContext.restoreGraphicsState()

let blue = NSColor(calibratedRed: 0.27, green: 0.49, blue: 0.98, alpha: 1)
for (index, height) in [76.0, 120.0, 174.0, 120.0, 76.0].enumerated() {
    let width: CGFloat = 32
    let x = 366 + CGFloat(index) * 65
    let wave = NSBezierPath(roundedRect: NSRect(x: x, y: 636, width: width, height: height), xRadius: width / 2, yRadius: width / 2)
    blue.setFill()
    wave.fill()
}

let ink = NSColor(calibratedRed: 0.075, green: 0.09, blue: 0.18, alpha: 1)
for centerX in [398.0, 626.0] {
    let eye = NSBezierPath(ovalIn: NSRect(x: centerX - 35, y: 464, width: 70, height: 77))
    ink.setFill()
    eye.fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: centerX - 18, y: 511, width: 15, height: 15)).fill()
}

for x in [288.0, 652.0] {
    NSGraphicsContext.saveGraphicsState()
    let blush = NSShadow()
    blush.shadowColor = NSColor(calibratedRed: 1, green: 0.50, blue: 0.60, alpha: 0.5)
    blush.shadowBlurRadius = 22
    blush.set()
    NSColor(calibratedRed: 1, green: 0.58, blue: 0.65, alpha: 0.68).setFill()
    NSBezierPath(ovalIn: NSRect(x: x, y: 390, width: 84, height: 54)).fill()
    NSGraphicsContext.restoreGraphicsState()
}

let smile = NSBezierPath()
smile.move(to: NSPoint(x: 451, y: 425))
smile.curve(to: NSPoint(x: 573, y: 425),
            controlPoint1: NSPoint(x: 475, y: 352),
            controlPoint2: NSPoint(x: 549, y: 352))
smile.lineWidth = 17
smile.lineCapStyle = .round
ink.setStroke()
smile.stroke()

canvas.unlockFocus()
guard let destination = CommandLine.arguments.dropFirst().first,
      let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to draw the TalkType icon")
}
try png.write(to: URL(fileURLWithPath: destination))
