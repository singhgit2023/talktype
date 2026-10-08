import AppKit
import Foundation

let talkTypeSyntheticEventTag: Int64 = 0x54545045

struct ShortcutChoice: Codable, Hashable, Identifiable {
    var modifiers: UInt
    var keyCode: UInt16?
    var keyLabel: String = ""
    var id: String { "\(modifiers)-\(keyCode.map(String.init) ?? "modifiers")" }
    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }
    var title: String {
        var parts: [String] = []
        for (flag, label) in [(NSEvent.ModifierFlags.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")] {
            if flags.contains(flag) { parts.append(label) }
        }
        if keyCode != nil { parts.append(keyLabel) }
        return parts.joined(separator: " ")
    }
    static let controlCommand = ShortcutChoice(modifiers: NSEvent.ModifierFlags([.control, .command]).rawValue)
    static let allCases: [ShortcutChoice] = [
        .controlCommand,
        ShortcutChoice(modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue),
        ShortcutChoice(modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue),
        ShortcutChoice(modifiers: NSEvent.ModifierFlags([.control, .shift]).rawValue),
        ShortcutChoice(modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue),
        ShortcutChoice(modifiers: NSEvent.ModifierFlags([.option, .shift]).rawValue)
    ]
}

@MainActor final class GlobalShortcut {
    var suspended = false { didSet { if suspended { release() } } }
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var choice: ShortcutChoice = .controlCommand
    private var isHeld = false
    private var didStart = false
    private var blockedUntilRelease = false
    private var holdWork: DispatchWorkItem?
    private let modifierMask: NSEvent.ModifierFlags = [.control, .command, .option, .shift]
    private let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]

    init() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            DispatchQueue.main.async { self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            DispatchQueue.main.async { self?.handle(event) }
            return event
        }
    }

    func configure(_ choice: ShortcutChoice) {
        holdWork?.cancel()
        if didStart { AppModel.shared.shortcutReleased() }
        isHeld = false
        didStart = false
        blockedUntilRelease = false
        self.choice = choice
    }

    private func release() {
        holdWork?.cancel()
        if didStart { AppModel.shared.shortcutReleased() }
        isHeld = false
        didStart = false
        blockedUntilRelease = false
    }

    private func handle(_ event: NSEvent) {
        guard !suspended else { return }
        guard event.cgEvent?.getIntegerValueField(.eventSourceUserData) != talkTypeSyntheticEventTag else { return }
        if event.type == .flagsChanged && !modifierKeyCodes.contains(event.keyCode) { return }
        let modifiersMatch = event.modifierFlags.intersection(modifierMask) == choice.flags
        if let key = choice.keyCode {
            if event.type == .keyDown, event.keyCode == key, modifiersMatch, !event.isARepeat, !didStart {
                isHeld = true
                didStart = true
                AppModel.shared.shortcutPressed()
            } else if (event.type == .keyUp && event.keyCode == key) || (event.type == .flagsChanged && !modifiersMatch) {
                release()
            }
            return
        }
        if event.type == .keyDown {
            guard isHeld, !didStart else { return }
            holdWork?.cancel()
            blockedUntilRelease = true
            return
        }
        guard event.type == .flagsChanged, modifiersMatch != isHeld else { return }
        if modifiersMatch {
            isHeld = true
            blockedUntilRelease = false
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isHeld, !self.blockedUntilRelease else { return }
                self.didStart = true
                AppModel.shared.shortcutPressed()
            }
            holdWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        } else { release() }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}
