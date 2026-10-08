import AppKit
import SwiftUI

@MainActor final class WindowControllers {
    static let shared = WindowControllers()
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func showSettings() {
        guard AppModel.shared.hasCompletedOnboarding else { showOnboarding(); return }
        if settingsWindow == nil {
            settingsWindow = makeWindow(title: "TalkType Settings", size: NSSize(width: 510, height: 640), content: SettingsView(model: .shared))
        }
        present(settingsWindow)
    }

    func showOnboarding() {
        settingsWindow?.orderOut(nil)
        if onboardingWindow == nil {
            onboardingWindow = makeWindow(title: "Welcome to TalkType", size: NSSize(width: 540, height: 600), content: OnboardingView(model: .shared))
        }
        present(onboardingWindow)
    }

    func closeOnboarding() {
        onboardingWindow?.close()
        showSettings()
    }

    private func makeWindow<Content: View>(title: String, size: NSSize, content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: content.environment(\.colorScheme, .light))
        return window
    }

    private func present(_ window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private final class DragAnywhereHostingView: NSHostingView<ListeningPanelView> {
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

@MainActor final class ListeningPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var presentationToken = 0

    func show(model: AppModel) {
        presentationToken += 1
        hideWork?.cancel()
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 66),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.alphaValue = 0
            panel.hasShadow = true
            panel.isMovableByWindowBackground = true
            panel.delegate = self
            panel.contentView = DragAnywhereHostingView(rootView: ListeningPanelView(model: model))
            self.panel = panel
            let defaults = UserDefaults.standard
            let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
            let point = defaults.object(forKey: "panelOriginX") == nil
                ? NSPoint(x: frame.midX - 230, y: frame.minY + 28)
                : NSPoint(x: defaults.double(forKey: "panelOriginX"), y: defaults.double(forKey: "panelOriginY"))
            panel.setFrameOrigin(point)
            keepOnScreen(panel)
        }
        panel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel?.animator().alphaValue = 1
        }
    }

    func hide(after seconds: TimeInterval = 0) { dismiss(after: seconds) }

    func dismiss(after seconds: TimeInterval = 0) {
        presentationToken += 1
        let token = presentationToken
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel, self.presentationToken == token else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 0
            } completionHandler: { [weak self, weak panel] in
                DispatchQueue.main.async {
                    guard let self, self.presentationToken == token else { return }
                    panel?.orderOut(nil)
                }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        UserDefaults.standard.set(panel.frame.minX, forKey: "panelOriginX")
        UserDefaults.standard.set(panel.frame.minY, forKey: "panelOriginY")
    }

    private func keepOnScreen(_ panel: NSPanel) {
        let screens = NSScreen.screens.map(\.visibleFrame)
        guard !screens.contains(where: { $0.intersects(panel.frame) }), let frame = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: frame.midX - 230, y: frame.minY + 28))
    }
}
