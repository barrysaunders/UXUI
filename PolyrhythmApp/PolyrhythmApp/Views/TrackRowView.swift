import SwiftUI

/// Compact horizontal view showing a track's pattern, name, and quick controls.
struct TrackRowView: View {
    let track: Track
    let currentStep: Int?
    let isSelected: Bool
    let onTap: () -> Void
    let onMuteToggle: () -> Void
    let onStepToggle: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Header
            HStack(spacing: 8) {
                // Voice icon + name
                Image(systemName: track.voiceType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(track.voiceType.color)

                Text(track.name)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(track.voiceType.color)

                Text("\(track.steps.count)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)

                Spacer()

                // Mute button
                Button(action: onMuteToggle) {
                    Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(track.isMuted ? .red.opacity(0.7) : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            // Step grid
            HStack(spacing: 2) {
                ForEach(0..<track.steps.count, id: \.self) { i in
                    let step = track.steps[i]
                    let isCurrent = currentStep == i

                    Button(action: { onStepToggle(i) }) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(stepColor(step: step, isCurrent: isCurrent))
                            .frame(height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(
                                        isCurrent ? track.voiceType.color : Color.white.opacity(0.05),
                                        lineWidth: isCurrent ? 1.5 : 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? track.voiceType.color.opacity(0.08) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? track.voiceType.color.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func stepColor(step: Step, isCurrent: Bool) -> Color {
        if step.isActive {
            let base = track.voiceType.color
            let brightness = isCurrent ? 1.0 : Double(step.velocity) * 0.6 + 0.2
            return base.opacity(track.isMuted ? brightness * 0.3 : brightness)
        } else {
            return isCurrent ? Color.white.opacity(0.08) : Color.white.opacity(0.03)
        }
    }
}
