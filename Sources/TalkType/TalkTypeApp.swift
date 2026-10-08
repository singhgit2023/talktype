import AppKit

@MainActor final class TalkTypeAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = UpdateController.shared
        statusItem = StatusItemController()
        if !AppModel.shared.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WindowControllers.shared.showOnboarding()
            }
        }
    }
}

@main @MainActor enum TalkTypeApp {
    private static var delegate: TalkTypeAppDelegate?

    static func main() {
        let application = NSApplication.shared
        let appDelegate = TalkTypeAppDelegate()
        delegate = appDelegate
        application.delegate = appDelegate
        application.run()
    }
}
