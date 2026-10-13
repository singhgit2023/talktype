import SwiftUI

private enum Palette {
    static let ink = Color(red: 0.08, green: 0.12, blue: 0.28)
    static let muted = Color(red: 0.40, green: 0.45, blue: 0.60)
    static let lavender = Color(red: 0.93, green: 0.92, blue: 1)
    static let peach = Color(red: 1, green: 0.93, blue: 0.90)
}

struct CompanionPopover: View {
    @ObservedObject var model: AppModel
    @State private var quitHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                MascotView(size: 40, phase: model.phase, animationsEnabled: model.mascotAnimations, level: model.audioLevel)
                Text("TalkType")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Spacer()
            }

            HStack(spacing: 7) {
                Image(systemName: model.microphonePermission ? "mic.fill" : "mic.slash.fill")
                    .foregroundStyle(model.microphonePermission ? .green : .orange)
                Text(model.microphonePermission ? "Microphone ready" : "Microphone access needed")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 2)

            Divider().opacity(0.4)
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
        .padding(14)
        .frame(width: 280)
        .background(LinearGradient(colors: [Palette.lavender.opacity(0.88), Palette.peach.opacity(0.62), Color.white], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
