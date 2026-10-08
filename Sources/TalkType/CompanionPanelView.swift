import AppKit
import SwiftUI

// These choices remain readable over any desktop wallpaper.
enum PanelAppearance: String, CaseIterable, Identifiable {
    case cream, white, blush, mint, lilac, sky, midnight
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var swatch: Color {
        switch self {
        case .cream: Color(red: 1, green: 0.96, blue: 0.92)
        case .white: .white
        case .blush: Color(red: 1, green: 0.91, blue: 0.94)
        case .mint: Color(red: 0.87, green: 0.97, blue: 0.92)
        case .lilac: Color(red: 0.93, green: 0.90, blue: 1)
        case .sky: Color(red: 0.88, green: 0.94, blue: 1)
        case .midnight: Color(red: 0.12, green: 0.14, blue: 0.20)
        }
    }
    var background: LinearGradient {
        let highlight: Color
        switch self {
        case .cream: highlight = Color(red: 1, green: 0.985, blue: 0.965)
        case .white: highlight = .white
        case .blush: highlight = Color(red: 1, green: 0.97, blue: 0.98)
        case .mint: highlight = Color(red: 0.96, green: 1, blue: 0.98)
        case .lilac: highlight = Color(red: 0.985, green: 0.97, blue: 1)
        case .sky: highlight = Color(red: 0.97, green: 0.985, blue: 1)
        case .midnight: highlight = Color(red: 0.17, green: 0.19, blue: 0.28)
        }
        return LinearGradient(colors: [highlight, swatch], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var ink: Color { self == .midnight ? .white : Color(red: 0.10, green: 0.12, blue: 0.20) }
    var muted: Color { self == .midnight ? Color.white.opacity(0.65) : Color(red: 0.43, green: 0.46, blue: 0.55) }
    var accent: Color {
        switch self {
        case .blush: Color(red: 0.91, green: 0.41, blue: 0.56)
        case .mint: Color(red: 0.17, green: 0.68, blue: 0.57)
        case .lilac: Color(red: 0.53, green: 0.43, blue: 0.88)
        case .sky: Color(red: 0.28, green: 0.58, blue: 0.91)
        case .midnight: Color(red: 0.60, green: 0.77, blue: 1)
        case .cream, .white: Color(red: 0.34, green: 0.52, blue: 0.95)
        }
    }
}

struct AudioWaveform: View, Animatable {
    var level: Float
    let color: Color
    let active: Bool
    let animated: Bool

    var animatableData: Double {
        get { Double(level) }
        set { level = Float(newValue) }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || !animated)) { timeline in
            Canvas { context, size in
                let time = active && animated ? timeline.date.timeIntervalSinceReferenceDate : 0
                let strength = min(1, max(0, Double(level)))
                let count = 15
                let center = Double(count - 1) / 2
                let step = (size.width - 24) / CGFloat(count - 1)
                var beads: [(rect: CGRect, tint: Color)] = []

                for index in 0..<count {
                    let distance = abs(Double(index) - center) / center
                    let envelope = pow(1 - distance, 1.35)
                    let flutter = 0.5 + 0.25 * sin(time * 5.1 + Double(index) * 0.91)
                        + 0.25 * sin(time * 3.3 - Double(index) * 1.37)
                    let motion = active ? (animated ? flutter : 0.5) : 0
                    let rise = active ? 0.32 + 0.68 * pow(strength, 0.7) : 0
                    let movementHeight: Double = 9 + 8 * motion
                    let activeHeight: Double = 5 + rise * movementHeight
                    let beadHeight: Double = 3.5 + envelope * (active ? activeHeight : 3.5)
                    let height = min(size.height - 4, CGFloat(beadHeight))
                    let x = 12 + CGFloat(index) * step
                    let rect = CGRect(x: x - 2, y: (size.height - height) / 2, width: 4, height: height)
                    let tint: Color = index < 4
                        ? Color(red: 0.40, green: 0.70, blue: 1)
                        : index < 10 ? color : index < 13
                        ? Color(red: 0.66, green: 0.59, blue: 0.99)
                        : Color(red: 1, green: 0.62, blue: 0.72)
                    beads.append((rect, tint))
                }

                if active {
                    context.drawLayer { glow in
                        glow.addFilter(.blur(radius: 4))
                        for bead in beads {
                            glow.fill(Path(roundedRect: bead.rect, cornerRadius: 2), with: .color(bead.tint.opacity(0.45)))
                        }
                    }
                }
                for bead in beads {
                    context.fill(
                        Path(roundedRect: bead.rect, cornerRadius: 2),
                        with: .linearGradient(
                            Gradient(colors: [bead.tint.opacity(0.72), bead.tint, bead.tint.opacity(0.76)]),
                            startPoint: CGPoint(x: bead.rect.midX, y: bead.rect.minY),
                            endPoint: CGPoint(x: bead.rect.midX, y: bead.rect.maxY)
                        )
                    )
                }
            }
        }
        .background(color.opacity(active ? 0.075 : 0.04), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(active ? 0.13 : 0.07), lineWidth: 0.7))
        .animation(.easeOut(duration: 0.18), value: level)
        .accessibilityLabel(active ? "Microphone active" : "Microphone idle")
    }
}

private struct TranscriptWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct AnimatedTranscriptLine: View {
    private struct Word: Identifiable {
        let id: String
        let text: String
    }

    let text: String
    let fontSize: Double
    let color: Color
    let animationsEnabled: Bool
    @State private var contentWidth: CGFloat = 0

    private var words: [Word] {
        let parts = text.split(whereSeparator: \.isWhitespace)
        return parts.enumerated().suffix(18).map { index, part in
            Word(id: "\(index)-\(part)", text: String(part))
        }
    }

    var body: some View {
        let visibleWords = words
        GeometryReader { geometry in
            HStack(spacing: fontSize * 0.25) {
                ForEach(visibleWords) { word in
                    Text(word.text)
                        .fixedSize()
                        .transition(animationsEnabled
                            ? .asymmetric(insertion: .opacity.combined(with: .offset(y: 1.5)), removal: .opacity)
                            : .identity)
                }
            }
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(color)
            .fixedSize(horizontal: true, vertical: false)
            .background(GeometryReader { measured in
                Color.clear.preference(key: TranscriptWidthKey.self, value: measured.size.width)
            })
            .offset(x: -max(0, contentWidth - geometry.size.width))
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .clipped()
            .animation(animationsEnabled ? .spring(response: 0.34, dampingFraction: 0.92) : nil,
                       value: visibleWords.map(\.id))
            .animation(animationsEnabled ? .easeInOut(duration: 0.25) : nil, value: contentWidth)
            .onPreferenceChange(TranscriptWidthKey.self) { contentWidth = $0 }
        }
        .frame(height: fontSize * 1.5)
        .accessibilityLabel(text)
    }
}

struct ListeningPanelView: View {
    @ObservedObject var model: AppModel

    private var currentLine: String {
        model.liveText.split(separator: "\n", omittingEmptySubsequences: false)
            .last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            .map(String.init) ?? ""
    }

    var body: some View {
        let appearance = model.panelAppearance
        HStack(spacing: 10) {
            MascotView(size: 44, phase: model.phase,
                       animationsEnabled: model.mascotAnimations, level: model.audioLevel)
            Group {
                if model.phase == .failure || currentLine.isEmpty {
                    Text(model.phase == .failure ? model.message : "Speak naturally. I'll type for you.")
                        .font(.system(size: model.transcriptFontSize, weight: .medium))
                        .foregroundStyle(model.phase == .failure ? appearance.ink : appearance.muted)
                        .lineLimit(1)
                } else {
                    AnimatedTranscriptLine(text: currentLine, fontSize: model.transcriptFontSize,
                                           color: appearance.ink, animationsEnabled: model.mascotAnimations)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if model.phase == .success {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(.green)
                    .frame(width: 108)
            } else if model.phase == .failure {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(.orange)
                    .frame(width: 108)
            } else {
                AudioWaveform(level: model.audioLevel, color: appearance.accent,
                              active: model.phase == .listening, animated: model.mascotAnimations)
                    .frame(width: 108, height: 24)
                    .overlay(alignment: .topTrailing) {
                        if model.phase == .listening {
                            Circle().fill(Color(red: 1, green: 0.42, blue: 0.48))
                                .frame(width: 6, height: 6).offset(x: 1, y: -2)
                                .accessibilityLabel("Recording")
                        }
                    }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .frame(width: 460, height: 66)
        .background(appearance.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(appearance.ink.opacity(0.10), lineWidth: 1))
        .accessibilityLabel("TalkType floating companion. Drag anywhere to move.")
    }
}
