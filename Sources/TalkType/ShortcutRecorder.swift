import AppKit
import SwiftUI

struct ShortcutRecorder: View {
    @ObservedObject var model: AppModel
    @State private var monitor: Any?
    @State private var recording = false
    @State private var candidate: NSEvent.ModifierFlags = []
    @State private var hint = "Hold a modifier pair, or modifiers plus a key."
    private let mask: NSEvent.ModifierFlags = [.control, .command, .option, .shift]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recording ? "Press your shortcut…" : model.shortcutChoice.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(minWidth: 110, alignment: .leading)
                Spacer()
                Button(recording ? "Cancel" : "Record shortcut") {
                    recording ? endRecording() : beginRecording()
                }
                .disabled(model.isRecording)
                if !recording {
                    Button("Reset") { model.shortcutChoice = .controlCommand }
                        .help("Use Control + Command")
                }
            }
            Text(recording ? hint + " Escape cancels." : "Hold to speak. Release to finish.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .onDisappear { endRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if recording { endRecording() }
        }
    }

    private func beginRecording() {
        model.suspendShortcut(true)
        candidate = []
        recording = true
        hint = "Hold a modifier pair, or modifiers plus a key."
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            let flags = event.modifierFlags.intersection(mask)
            if event.type == .keyDown {
                if event.keyCode == 53 { endRecording(); return nil }
                guard !flags.intersection([.control, .option, .command]).isEmpty else {
                    hint = "Include Control, Option, or Command with a key."
                    return nil
                }
                let special: [UInt16: String] = [49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 123: "←", 124: "→", 125: "↓", 126: "↑"]
                let label = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
                model.shortcutChoice = ShortcutChoice(modifiers: flags.rawValue, keyCode: event.keyCode, keyLabel: label)
                endRecording()
                return nil
            }
            if flags.rawValue.nonzeroBitCount >= candidate.rawValue.nonzeroBitCount { candidate = flags }
            if flags.isEmpty, candidate.rawValue.nonzeroBitCount >= 2 {
                model.shortcutChoice = ShortcutChoice(modifiers: candidate.rawValue)
                endRecording()
            } else if flags.isEmpty, !candidate.isEmpty {
                hint = "Hold at least two modifier keys."
                candidate = []
            }
            return event
        }
    }

    private func endRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        model.suspendShortcut(false)
    }
}
