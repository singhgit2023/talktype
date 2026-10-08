import SwiftUI

private enum Palette {
    static let ink = Color(red: 0.08, green: 0.12, blue: 0.28)
    static let muted = Color(red: 0.40, green: 0.45, blue: 0.60)
    static let blue = Color(red: 0.25, green: 0.47, blue: 0.96)
    static let lavender = Color(red: 0.93, green: 0.92, blue: 1)
    static let peach = Color(red: 1, green: 0.93, blue: 0.90)
    static let mint = Color(red: 0.88, green: 0.97, blue: 0.94)
}

struct CompanionPopover: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var updates = UpdateController.shared
    @State private var primaryHovered = false
    @State private var quitHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MascotView(size: 44, phase: model.phase, animationsEnabled: model.mascotAnimations, level: model.audioLevel)
                VStack(alignment: .leading, spacing: 3) {
                    Text("TalkType").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                    Text("Just speak. It types for you.").font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Circle()
                    .fill(model.phase == .listening ? .red : model.phase == .failure ? .orange : .green)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(model.message)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: model.phase == .listening ? "waveform" : model.phase == .failure ? "exclamationmark.circle.fill" : "sparkle")
                        .foregroundStyle(model.phase == .failure ? .orange : Palette.blue)
                    Text(model.message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(3)
                }
                Text(model.liveText.isEmpty ? "Hold \(model.shortcutChoice.title) to type as you speak." : model.liveText)
                    .font(.system(size: 13))
                    .foregroundStyle(model.liveText.isEmpty ? Palette.muted : Palette.ink)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)

                Button {
                    model.toggleRecording()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: model.phase == .listening ? "stop.fill" : "mic.fill")
                        Text(model.phase == .listening ? "Stop listening" : "Start voice typing")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(model.shortcutChoice.title)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(height: 40)
                    .background(model.phase == .listening ? Color(red: 0.93, green: 0.28, blue: 0.29) : Palette.blue, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(model.phase == .preparing || model.phase == .finishing)
                .scaleEffect(primaryHovered ? 1.018 : 1)
                .shadow(color: Palette.blue.opacity(primaryHovered ? 0.18 : 0), radius: 10, y: 4)
                .animation(.easeOut(duration: 0.16), value: primaryHovered)
                .onHover { primaryHovered = $0 }
            }
            .padding(13)
            .background(.white.opacity(0.83), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.8), lineWidth: 1))
            .shadow(color: Palette.ink.opacity(0.07), radius: 16, y: 7)

            HStack(spacing: 7) {
                Image(systemName: model.microphonePermission ? "mic.fill" : "mic.slash.fill")
                    .foregroundStyle(model.microphonePermission ? .green : .orange)
                Text(model.microphonePermission ? "Microphone ready" : "Microphone access needed")
                Spacer()
                Text("On your Mac")
                    .foregroundStyle(Palette.muted)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 3)

            Button { model.showCompanion() } label: {
                Label("Show floating companion", systemImage: "rectangle.on.rectangle")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.muted)

            if updates.isConfigured {
                Button { updates.checkForUpdates() } label: {
                    Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.muted)
                .disabled(!updates.canCheckForUpdates)
            }

            Divider().opacity(0.5)
            HStack(spacing: 8) {
                Button { WindowControllers.shared.showSettings() } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 10))
                }
                Button { NSApp.terminate(nil) } label: {
                    Label("Quit TalkType", systemImage: "power")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .foregroundStyle(Color(red: 0.72, green: 0.24, blue: 0.29))
                        .background(Color(red: 1, green: 0.91, blue: 0.91).opacity(quitHovered ? 1 : 0.75), in: RoundedRectangle(cornerRadius: 10))
                }
                .keyboardShortcut("q", modifiers: .command)
                .onHover { quitHovered = $0 }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.ink)
        }
        .padding(16)
        .frame(width: 320)
        .background(LinearGradient(colors: [Palette.lavender.opacity(0.88), Palette.peach.opacity(0.62), Color.white], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
