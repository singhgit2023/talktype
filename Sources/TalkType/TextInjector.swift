import AppKit
import ApplicationServices
import Foundation

enum TalkTypeError: LocalizedError {
    case microphonePermission
    case speechPermission
    case accessibilityPermission
    case recognitionUnavailable
    case onDeviceUnavailable
    case microphoneSelection
    case noSpeech
    case noTarget
    case shortcutUnavailable

    var errorDescription: String? {
        switch self {
        case .microphonePermission: "Allow microphone access in System Settings to start listening."
        case .speechPermission: "Allow Speech Recognition in System Settings to turn your voice into text."
        case .accessibilityPermission: "Allow TalkType in Privacy & Security → Accessibility so it can type into your apps."
        case .recognitionUnavailable: "Speech recognition is unavailable right now. Try again in a moment."
        case .onDeviceUnavailable: "On-device speech recognition is unavailable for this language. Choose another language in Settings."
        case .microphoneSelection: "That microphone could not be selected. Try System default in Settings."
        case .noSpeech: "I didn't catch any words. Try speaking a little closer to your microphone."
        case .noTarget: "Open a text field in another app, then try your shortcut again."
        case .shortcutUnavailable: "That shortcut is being used by another app. Pick a different one in Settings."
        }
    }
}

enum TextInjector {
    static func accessibilityIsGranted(prompt: Bool) -> Bool {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary)
    }

}

@MainActor final class LiveTextInjector {
    private let app: NSRunningApplication
    private let pasteboard = NSPasteboard.general
    private var savedClipboard: [NSPasteboardItem]
    private var ownChangeCount: Int?
    private(set) var insertedText = ""
    // Once a line is complete, later recognition revisions may change only the current line.
    private var protectedPrefix = ""

    init(app: NSRunningApplication) {
        self.app = app
        savedClipboard = Self.snapshot(NSPasteboard.general)
    }

    func prepare() async throws {
        guard !app.isTerminated else { throw TalkTypeError.noTarget }
        guard TextInjector.accessibilityIsGranted(prompt: true) else { throw TalkTypeError.accessibilityPermission }
        app.activate()
        try await Task.sleep(nanoseconds: 130_000_000)
    }

    func update(_ sourceText: String) async throws {
        guard !app.isTerminated,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
            throw TalkTypeError.noTarget
        }
        guard !sourceText.isEmpty else { return }
        var desired = sourceText
        if !protectedPrefix.isEmpty && !sourceText.hasPrefix(protectedPrefix) {
            // Speech recognition can restart its partial transcript after a pause.
            // Keep completed paragraphs and use only the new current line.
            let latestLine = sourceText.split(separator: "\n", omittingEmptySubsequences: false).last.map(String.init) ?? sourceText
            desired = protectedPrefix + latestLine
        }
        let previousTail = String(insertedText.dropFirst(protectedPrefix.count))
        let incomingTail = String(desired.dropFirst(protectedPrefix.count))
        if previousTail.count >= 35 && previousTail.count - incomingTail.count > 18 {
            // A reset must not erase a paragraph that is already in another app.
            protectedPrefix = insertedText + (insertedText.hasSuffix("\n") ? "" : "\n")
            desired = protectedPrefix + incomingTail
        }
        guard desired != insertedText else { return }
        let old = Array(insertedText)
        let new = Array(desired)
        var common = 0
        while common < old.count && common < new.count && old[common] == new[common] { common += 1 }
        let protectedCount = protectedPrefix.count
        guard common >= protectedCount else { return }
        for _ in common..<old.count { try postKey(51, flags: []) }
        let addition = String(new.dropFirst(common))
        if !addition.isEmpty { try await paste(addition) }
        insertedText = desired
        if let newline = insertedText.lastIndex(of: "\n") {
            protectedPrefix = String(insertedText[...newline])
        }
    }

    func finish() {
        if let ownChangeCount, pasteboard.changeCount == ownChangeCount {
            pasteboard.clearContents()
            if !savedClipboard.isEmpty { pasteboard.writeObjects(savedClipboard) }
        }
        ownChangeCount = nil
    }

    private func paste(_ text: String) async throws {
        if let ownChangeCount, pasteboard.changeCount != ownChangeCount {
            savedClipboard = Self.snapshot(pasteboard)
        }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ownChangeCount = pasteboard.changeCount
        try postKey(9, flags: .maskCommand)
        try await Task.sleep(nanoseconds: 75_000_000)
    }

    private func postKey(_ code: CGKeyCode, flags: CGEventFlags) throws {
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else {
            throw TalkTypeError.accessibilityPermission
        }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: talkTypeSyntheticEventTag)
        up.setIntegerValueField(.eventSourceUserData, value: talkTypeSyntheticEventTag)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []
    }
}
