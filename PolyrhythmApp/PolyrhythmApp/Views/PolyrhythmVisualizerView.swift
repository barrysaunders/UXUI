import SwiftUI

/// Circular polyrhythm visualizer showing concentric rings for each track.
/// Each ring has dots for steps, with active steps highlighted and
/// the current step indicated by a bright pulse.
struct PolyrhythmVisualizerView: View {
    let tracks: [Track]
    let currentSteps: [UUID: Int]
    let isPlaying: Bool

    @State private var pulsePhase: Double = 0.0

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 - 20

            ZStack {
                // Background glow
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color(red: 0.05, green: 0.02, blue: 0.1)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: maxRadius * 1.2
                )

                // Center dot
                Circle()
                    .fill(isPlaying ? Color.white.opacity(0.8) : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .position(center)
                    .scaleEffect(isPlaying ? 1.0 + sin(pulsePhase) * 0.3 : 1.0)

                // Concentric rings for each track
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    let ringRadius = ringRadius(index: index, total: tracks.count, maxRadius: maxRadius)

                    // Ring guide circle
                    Circle()
                        .stroke(track.voiceType.color.opacity(0.1), lineWidth: 1)
                        .frame(width: ringRadius * 2, height: ringRadius * 2)
                        .position(center)

                    // Step dots
                    ForEach(0..<track.steps.count, id: \.self) { stepIndex in
                        let angle = stepAngle(step: stepIndex, total: track.steps.count)
                        let pos = pointOnCircle(center: center, radius: ringRadius, angle: angle)
                        let step = track.steps[stepIndex]
                        let isCurrent = currentSteps[track.id] == stepIndex

                        stepDot(
                            step: step,
                            isCurrent: isCurrent,
                            isMuted: track.isMuted,
                            color: track.voiceType.color,
                            position: pos
                        )
                    }

                    // Current position indicator (arc sweep)
                    if isPlaying, let currentStep = currentSteps[track.id] {
                        let angle = stepAngle(step: currentStep, total: track.steps.count)
                        let pos = pointOnCircle(center: center, radius: ringRadius, angle: angle)

                        Circle()
                            .fill(track.voiceType.color.opacity(0.4))
                            .frame(width: 20, height: 20)
                            .blur(radius: 6)
                            .position(pos)
                    }
                }

                // Track labels
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    let ringRadius = ringRadius(index: index, total: tracks.count, maxRadius: maxRadius)
                    let labelPos = CGPoint(x: center.x, y: center.y - ringRadius - 10)

                    Text(track.voiceType.rawValue)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(track.voiceType.color.opacity(0.6))
                        .position(labelPos)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                pulsePhase = .pi * 2
            }
        }
    }

    // MARK: - Helpers

    private func ringRadius(index: Int, total: Int, maxRadius: CGFloat) -> CGFloat {
        let minRadius: CGFloat = 30
        guard total > 1 else { return maxRadius * 0.6 }
        let fraction = CGFloat(index + 1) / CGFloat(total + 1)
        return minRadius + (maxRadius - minRadius) * fraction
    }

    private func stepAngle(step: Int, total: Int) -> Double {
        let fraction = Double(step) / Double(total)
        return fraction * .pi * 2.0 - .pi / 2.0  // Start from top
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    @ViewBuilder
    private func stepDot(step: Step, isCurrent: Bool, isMuted: Bool, color: Color, position: CGPoint) -> some View {
        let size: CGFloat = step.isActive ? (isCurrent ? 12 : 8) : 4
        let opacity: Double = isMuted ? 0.2 : (step.isActive ? (isCurrent ? 1.0 : 0.7) : 0.2)

        Circle()
            .fill(step.isActive ? color.opacity(opacity) : Color.gray.opacity(opacity))
            .frame(width: size, height: size)
            .shadow(color: isCurrent && step.isActive ? color : .clear, radius: isCurrent ? 8 : 0)
            .position(position)
            .animation(.easeOut(duration: 0.08), value: isCurrent)
    }
}
