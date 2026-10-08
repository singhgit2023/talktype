import SwiftUI

private enum SoftUI {
    static let ink = Color(red: 0.09, green: 0.12, blue: 0.25)
    static let muted = Color(red: 0.40, green: 0.44, blue: 0.58)
    static let blue = Color(red: 0.28, green: 0.48, blue: 0.94)
    static let cream = Color(red: 1, green: 0.96, blue: 0.93)
    static let lavender = Color(red: 0.93, green: 0.92, blue: 1)
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var updates = UpdateController.shared
    private let languages = [
        ("en-US", "English (United States)"), ("en-GB", "English (United Kingdom)"),
        ("en-IN", "English (India)"), ("es-ES", "Spanish"),
        ("fr-FR", "French"), ("de-DE", "German"),
        ("it-IT", "Italian"), ("ja-JP", "Japanese")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MascotView(size: 52, phase: model.phase, animationsEnabled: model.mascotAnimations)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TalkType Settings").font(.system(size: 21, weight: .bold, design: .rounded))
                    Text("Make your companion feel right at home.").font(.system(size: 12)).foregroundStyle(SoftUI.muted)
                }
            }
            Form {
                Section("Speak") {
                    Picker("Microphone", selection: $model.microphoneID) {
                        Text("System default").tag(UInt32(0))
                        ForEach(model.microphoneInputs) { input in Text(input.name).tag(input.id) }
                    }
                    Picker("Language", selection: $model.languageID) {
                        ForEach(languages, id: \.0) { id, name in Text(name).tag(id) }
                    }
                    Toggle("Automatic formatting", isOn: $model.automaticFormatting)
                }
                Section("Hold shortcut") { ShortcutRecorder(model: model).padding(.vertical, 3) }
                Section("Floating companion") {
                    Picker("Appearance", selection: $model.panelAppearance) {
                        ForEach(PanelAppearance.allCases) { appearance in
                            HStack(spacing: 7) {
                                Circle().fill(appearance.swatch).frame(width: 11, height: 11)
                                Text(appearance.title)
                            }
                                .tag(appearance)
                        }
                    }
                    HStack {
                        Text("Transcript size")
                        Slider(value: $model.transcriptFontSize, in: 12...19, step: 1)
                        Text("\(Int(model.transcriptFontSize))").monospacedDigit().foregroundStyle(.secondary)
                    }
                    Toggle("Companion animations", isOn: $model.mascotAnimations)
                    Toggle("Gentle sound cues", isOn: $model.soundCuesEnabled)
                    Button("Show floating companion") { model.showCompanion() }
                }
                Section("General") {
                    Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                }
                Section("Updates") {
                    Toggle("Check automatically", isOn: Binding(
                        get: { updates.automaticallyChecksForUpdates },
                        set: { updates.setAutomaticChecks($0) }
                    ))
                    .disabled(!updates.isConfigured)
                    Button("Check for Updates…") { updates.checkForUpdates() }
                        .disabled(!updates.canCheckForUpdates)
                    if !updates.isConfigured {
                        Text("Update checks will be available with the first published release.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            HStack {
                Button("Show welcome guide") { WindowControllers.shared.showOnboarding() }
                Spacer()
                Button("Refresh microphones") { model.refreshMicrophones() }
            }
            .font(.system(size: 11))
            .foregroundStyle(SoftUI.muted)
            Text("Made with ❤️ by MacLabb")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(SoftUI.muted)
                .padding(.horizontal, 13).padding(.vertical, 6)
                .background(.white.opacity(0.72), in: Capsule())
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .frame(width: 510, height: 640)
        .background(LinearGradient(colors: [SoftUI.lavender, .white], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("WELCOME TO TALKTYPE")
                    .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.3)
                    .foregroundStyle(SoftUI.blue)
                Spacer()
                Text("\(page + 1) / 4").font(.system(size: 11, weight: .semibold)).foregroundStyle(SoftUI.muted)
            }
            Spacer(minLength: 14)
            MascotView(size: page == 0 ? 100 : 72, phase: page == 1 ? .listening : .idle, animationsEnabled: model.mascotAnimations)
                .padding(.bottom, 16)
            Text(["Hello, I'm TalkType", "Make it your shortcut", "Pick your look", "Ready to speak? "][page])
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(SoftUI.ink)
            Text([
                "A little Mac companion that types your words wherever your cursor is. I live in your menu bar and stay out of the way.",
                "Record a shortcut you can comfortably hold. Your words appear as you speak; release the keys to finish.",
                "Drag the floating companion anywhere on screen. Choose the style and text size that feel comfortable.",
                "Allow these three permissions so TalkType can listen, recognize speech, and type into your apps."
            ][page])
                .font(.system(size: 13)).foregroundStyle(SoftUI.muted)
                .multilineTextAlignment(.center).frame(maxWidth: 405).padding(.top, 9)
            pageContent
                .frame(maxWidth: 425)
                .padding(.top, 20)
            Spacer(minLength: 18)
            HStack {
                if page > 0 {
                    Button("Back") { withAnimation(.easeInOut(duration: 0.2)) { page -= 1 } }
                        .buttonStyle(.plain).foregroundStyle(SoftUI.muted)
                }
                Spacer()
                Button(page == 3 ? "Start using TalkType" : "Continue") {
                    if page == 3 {
                        model.completeOnboarding()
                        WindowControllers.shared.closeOnboarding()
                    } else { withAnimation(.easeInOut(duration: 0.2)) { page += 1 } }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).frame(height: 38)
                .background(SoftUI.blue, in: RoundedRectangle(cornerRadius: 11))
            }
        }
        .padding(28)
        .frame(width: 540, height: 600)
        .background(LinearGradient(colors: [SoftUI.lavender, SoftUI.cream, .white], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    @ViewBuilder private var pageContent: some View {
        switch page {
        case 0:
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                Text("Speak naturally. I'll take care of the typing.")
            }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(SoftUI.blue)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.white.opacity(0.8), in: Capsule())
        case 1:
            ShortcutRecorder(model: model)
                .padding(17)
                .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 16))
        case 2:
            VStack(spacing: 13) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
                    ForEach(PanelAppearance.allCases) { appearance in
                        Button { model.panelAppearance = appearance } label: {
                            HStack(spacing: 5) {
                                Circle().fill(appearance.swatch)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(SoftUI.ink.opacity(0.12), lineWidth: 0.5))
                                Text(appearance.title).font(.system(size: 10, weight: .medium))
                            }
                            .frame(maxWidth: .infinity).frame(height: 28)
                            .background(model.panelAppearance == appearance ? SoftUI.blue.opacity(0.12) : .white.opacity(0.8),
                                        in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(model.panelAppearance == appearance ? SoftUI.blue.opacity(0.5) : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(spacing: 13) {
                    MascotView(size: 42, animationsEnabled: model.mascotAnimations)
                    Text("Your words appear here")
                        .font(.system(size: 12)).foregroundStyle(model.panelAppearance.muted)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    AudioWaveform(level: 0.35, color: model.panelAppearance.accent, active: true, animated: model.mascotAnimations)
                        .frame(width: 108, height: 24)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(model.panelAppearance.background, in: RoundedRectangle(cornerRadius: 15))
                    .font(.system(size: 12))
            }
            .padding(16)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 17))
        default:
            VStack(spacing: 9) {
                permissionRow("Microphone", detail: "Hear you only when recording", icon: "mic.fill", granted: model.microphonePermission) {
                    Task { await model.requestMicrophone() }
                }
                permissionRow("Speech Recognition", detail: "Turn your speech into text on this Mac", icon: "waveform", granted: model.speechPermission) {
                    Task { await model.requestSpeech() }
                }
                permissionRow("Accessibility", detail: "Type into the app under your cursor", icon: "keyboard", granted: model.accessibilityPermission) {
                    model.requestAccessibility()
                }
            }
        }
    }

    private func permissionRow(_ title: String, detail: String, icon: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(SoftUI.blue).frame(width: 27)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(SoftUI.ink)
                Text(detail).font(.system(size: 10)).foregroundStyle(SoftUI.muted)
            }
            Spacer()
            Button(granted ? "Allowed" : "Allow", action: action)
                .buttonStyle(.bordered).disabled(granted)
        }
        .padding(.horizontal, 13).frame(height: 53)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
    }
}
