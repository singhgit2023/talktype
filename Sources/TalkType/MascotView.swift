import SwiftUI

struct MascotView: View {
    let size: CGFloat
    var phase: AppModel.Phase = .idle
    var animationsEnabled = true
    var level: Float = 0
    @State private var blink = false
    @State private var bounce = false
    @State private var wave = false

    private var isListening: Bool { phase == .listening || phase == .finishing }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(LinearGradient(colors: [.white, Color(red: 1, green: 0.97, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color(red: 0.19, green: 0.20, blue: 0.39).opacity(0.14), radius: size * 0.13, y: size * 0.08)

            HStack(alignment: .center, spacing: size * 0.05) {
                ForEach(0..<5) { index in
                    Capsule()
                        .fill(Color(red: 0.28, green: 0.50, blue: 0.99))
                        .frame(width: size * 0.055, height: size * (index == 2 ? 0.29 : index == 1 || index == 3 ? 0.20 : 0.10) * (wave && isListening ? 1.14 + CGFloat(level) * 0.55 : 1))
                        .rotationEffect(.degrees(index == 0 ? 18 : index == 4 ? -18 : index == 1 ? 8 : index == 3 ? -8 : 0))
                }
            }
            .offset(y: -size * 0.20)

            HStack(spacing: size * 0.29) {
                Circle().fill(Color(red: 0.08, green: 0.10, blue: 0.20))
                    .frame(width: size * 0.10, height: blink ? size * 0.018 : size * 0.12)
                Circle().fill(Color(red: 0.08, green: 0.10, blue: 0.20))
                    .frame(width: size * 0.10, height: blink ? size * 0.018 : size * 0.12)
            }
            .offset(y: size * 0.075)

            HStack(spacing: size * 0.47) {
                Ellipse().fill(Color(red: 1, green: 0.60, blue: 0.65).opacity(0.70))
                    .frame(width: size * 0.18, height: size * 0.105)
                Ellipse().fill(Color(red: 1, green: 0.60, blue: 0.65).opacity(0.70))
                    .frame(width: size * 0.18, height: size * 0.105)
            }
            .blur(radius: size * 0.015)
            .offset(y: size * 0.19)

            SmileShape()
                .stroke(Color(red: 0.08, green: 0.10, blue: 0.20), style: StrokeStyle(lineWidth: max(1.5, size * 0.034), lineCap: .round))
                .frame(width: size * 0.19, height: size * 0.12)
                .offset(y: size * 0.17)
        }
        .frame(width: size, height: size)
        .offset(y: bounce && (isListening || phase == .success) ? -size * (phase == .success ? 0.07 : 0.02 + CGFloat(level) * 0.025) : 0)
        .accessibilityLabel("TalkType companion")
        .task(id: animationsEnabled) {
            guard animationsEnabled else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_400_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.10)) { blink = true }
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.easeInOut(duration: 0.14)) { blink = false }
            }
        }
        .onAppear {
            if isListening && animationsEnabled {
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    bounce = true
                    wave = true
                }
            }
        }
        .onChange(of: isListening) { _, active in
            if active && animationsEnabled {
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    bounce = true
                    wave = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { bounce = false; wave = false }
            }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .success && animationsEnabled {
                bounce = false
                withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) { bounce = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                    withAnimation(.easeOut(duration: 0.2)) { bounce = false }
                }
            }
        }
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 1.6))
        return path
    }
}
