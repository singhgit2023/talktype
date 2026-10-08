import AppKit
import SwiftUI

@MainActor final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: 30)
    private let popover = NSPopover()

    override init() {
        super.init()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: CompanionPopover(model: .shared))
        if let button = item.button {
            button.image = Self.mascotIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "TalkType — click for settings and voice typing"
            button.setAccessibilityLabel("TalkType menu")
            button.target = self
            button.action = #selector(togglePopover)
        }
        item.isVisible = true
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }

    private static func mascotIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { _ in
            let body = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 19, height: 19), xRadius: 6, yRadius: 6)
            NSColor.white.setFill(); body.fill()
            NSColor.black.withAlphaComponent(0.24).setStroke(); body.lineWidth = 0.6; body.stroke()
            NSColor(calibratedRed: 0.29, green: 0.52, blue: 0.98, alpha: 1).setFill()
            for (x, height) in [(8.0, 3.0), (10.4, 5.0), (12.8, 3.0)] {
                NSBezierPath(roundedRect: NSRect(x: x, y: 15.3, width: 1.3, height: height), xRadius: 0.65, yRadius: 0.65).fill()
            }
            NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.21, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 6, y: 10, width: 2.7, height: 3.2)).fill()
            NSBezierPath(ovalIn: NSRect(x: 13.3, y: 10, width: 2.7, height: 3.2)).fill()
            let smile = NSBezierPath()
            smile.move(to: NSPoint(x: 8.5, y: 7.7))
            smile.curve(to: NSPoint(x: 13.5, y: 7.7), controlPoint1: NSPoint(x: 9.4, y: 4.6), controlPoint2: NSPoint(x: 12.6, y: 4.6))
            NSColor(calibratedWhite: 0.13, alpha: 1).setStroke()
            smile.lineWidth = 1.4; smile.lineCapStyle = .round; smile.stroke()
            NSColor(calibratedRed: 1, green: 0.62, blue: 0.67, alpha: 0.85).setFill()
            NSBezierPath(ovalIn: NSRect(x: 3.7, y: 7, width: 3.8, height: 2.2)).fill()
            NSBezierPath(ovalIn: NSRect(x: 14.5, y: 7, width: 3.8, height: 2.2)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
