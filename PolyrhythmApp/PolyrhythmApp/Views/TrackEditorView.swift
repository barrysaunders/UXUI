import SwiftUI

/// Detailed editor for a single track's parameters including synth controls,
/// step editor, and per-step velocity/note editing.
struct TrackEditorView: View {
    @ObservedObject var viewModel: SessionViewModel
    let trackIndex: Int

    @State private var selectedTab = 0

    private var track: Track {
        guard trackIndex < viewModel.tracks.count else {
            return Track(voiceType: .kick)
        }
        return viewModel.tracks[trackIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Tab selector
            tabBar

            // Content
            ScrollView {
                switch selectedTab {
                case 0: patternEditor
                case 1: synthControls
                case 2: evolutionControls
                default: patternEditor
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(Color.black)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: track.voiceType.icon)
                .foregroundColor(track.voiceType.color)

            Text(track.name)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(track.voiceType.color)

            Spacer()

            // Voice type picker
            Menu {
                ForEach(VoiceType.allCases) { voice in
                    Button(voice.rawValue) {
                        viewModel.updateTrack(at: trackIndex) { t in
                            t.voiceType = voice
                            t.name = voice.rawValue
                        }
                    }
                }
            } label: {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            Button(action: { viewModel.showTrackEditor = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(track.voiceType.color.opacity(0.1))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Pattern", index: 0)
            tabButton("Synth", index: 1)
            tabButton("Evolve", index: 2)
        }
        .background(Color.white.opacity(0.03))
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            Text(title)
                .font(.system(size: 12, weight: selectedTab == index ? .bold : .regular, design: .monospaced))
                .foregroundColor(selectedTab == index ? track.voiceType.color : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedTab == index ? track.voiceType.color.opacity(0.1) : .clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pattern Editor

    private var patternEditor: some View {
        VStack(spacing: 16) {
            // Step count control
            HStack {
                Text("Steps")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Button("-") {
                    viewModel.updateTrack(at: trackIndex) { t in
                        t.setStepCount(t.steps.count - 1)
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

                Text("\(track.steps.count)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(track.voiceType.color)
                    .frame(width: 30)

                Button("+") {
                    viewModel.updateTrack(at: trackIndex) { t in
                        t.setStepCount(t.steps.count + 1)
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            }

            // Large step grid with velocity bars
            VStack(spacing: 4) {
                // Velocity bars
                HStack(spacing: 2) {
                    ForEach(0..<track.steps.count, id: \.self) { i in
                        let step = track.steps[i]
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 1)
                                .fill(step.isActive ? track.voiceType.color.opacity(Double(step.velocity)) : Color.gray.opacity(0.1))
                                .frame(height: CGFloat(step.velocity) * 40)
                        }
                        .frame(height: 40)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let vel = 1.0 - Float(value.location.y / 40)
                                    viewModel.updateTrack(at: trackIndex) { t in
                                        t.steps[i].velocity = max(0.1, min(1.0, vel))
                                    }
                                }
                        )
                    }
                }

                // Step buttons
                HStack(spacing: 2) {
                    ForEach(0..<track.steps.count, id: \.self) { i in
                        Button(action: {
                            viewModel.updateTrack(at: trackIndex) { t in
                                t.steps[i].isActive.toggle()
                            }
                        }) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(track.steps[i].isActive ? track.voiceType.color : Color.white.opacity(0.05))
                                .frame(height: 30)
                                .overlay(
                                    Text("\(i + 1)")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(track.steps[i].isActive ? .black.opacity(0.5) : .gray.opacity(0.3))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Note lanes (for melodic voices)
                if track.voiceType != .kick && track.voiceType != .snare &&
                   track.voiceType != .hihat && track.voiceType != .perc {
                    VStack(spacing: 2) {
                        Text("Notes")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 2) {
                            ForEach(0..<track.steps.count, id: \.self) { i in
                                let step = track.steps[i]
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(step.isActive ? track.voiceType.color.opacity(0.5) : Color.gray.opacity(0.1))
                                        .frame(height: max(4, CGFloat(step.note) * 3))
                                }
                                .frame(height: 50)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let note = Int((1.0 - value.location.y / 50) * 14)
                                            viewModel.updateTrack(at: trackIndex) { t in
                                                t.steps[i].note = max(0, min(14, note))
                                            }
                                        }
                                )
                            }
                        }
                    }
                }
            }

            // Quick actions
            HStack(spacing: 8) {
                quickActionButton("Random") {
                    viewModel.randomizeTrack(at: trackIndex)
                }
                quickActionButton("Smart") {
                    EvolutionEngine.generateSmart(track: &viewModel.tracks[trackIndex], scale: viewModel.scale)
                }
                quickActionButton("Euclid") {
                    let pulses = Int.random(in: 2...max(3, track.steps.count - 1))
                    viewModel.euclideanize(trackIndex: trackIndex, pulses: pulses)
                }
                quickActionButton("Clear") {
                    viewModel.updateTrack(at: trackIndex) { t in
                        for i in t.steps.indices {
                            t.steps[i].isActive = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Synth Controls

    private var synthControls: some View {
        VStack(spacing: 16) {
            paramSlider("Volume", value: track.volume) { v in
                viewModel.updateTrack(at: trackIndex) { $0.volume = v }
            }
            paramSlider("Pan", value: (track.pan + 1) / 2, label: panLabel) { v in
                viewModel.updateTrack(at: trackIndex) { $0.pan = v * 2 - 1 }
            }

            Divider().background(Color.gray.opacity(0.3))

            paramSlider("Filter Cutoff", value: track.filterCutoff) { v in
                viewModel.updateTrack(at: trackIndex) { $0.filterCutoff = v }
            }
            paramSlider("Resonance", value: track.filterResonance) { v in
                viewModel.updateTrack(at: trackIndex) { $0.filterResonance = v }
            }

            Divider().background(Color.gray.opacity(0.3))

            paramSlider("Attack", value: track.attack) { v in
                viewModel.updateTrack(at: trackIndex) { $0.attack = v }
            }
            paramSlider("Decay", value: track.decay) { v in
                viewModel.updateTrack(at: trackIndex) { $0.decay = v }
            }
            paramSlider("Sustain", value: track.sustain) { v in
                viewModel.updateTrack(at: trackIndex) { $0.sustain = v }
            }
            paramSlider("Release", value: track.release) { v in
                viewModel.updateTrack(at: trackIndex) { $0.release = v }
            }

            Divider().background(Color.gray.opacity(0.3))

            paramSlider("Reverb", value: track.reverbSend) { v in
                viewModel.updateTrack(at: trackIndex) { $0.reverbSend = v }
            }
            paramSlider("Delay", value: track.delaySend) { v in
                viewModel.updateTrack(at: trackIndex) { $0.delaySend = v }
            }

            Divider().background(Color.gray.opacity(0.3))

            // Pitch offset
            HStack {
                Text("Pitch")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Button("-") {
                    viewModel.updateTrack(at: trackIndex) { $0.pitchOffset -= 1 }
                }
                .foregroundColor(.white)
                Text("\(track.pitchOffset > 0 ? "+" : "")\(track.pitchOffset)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(track.voiceType.color)
                    .frame(width: 40)
                Button("+") {
                    viewModel.updateTrack(at: trackIndex) { $0.pitchOffset += 1 }
                }
                .foregroundColor(.white)
            }

            // Randomize params button
            quickActionButton("Randomize Sound") {
                EvolutionEngine.randomizeParameters(track: &viewModel.tracks[trackIndex])
            }
        }
    }

    // MARK: - Evolution Controls

    private var evolutionControls: some View {
        VStack(spacing: 16) {
            paramSlider("Evolution Rate", value: track.evolutionRate) { v in
                viewModel.updateTrack(at: trackIndex) { $0.evolutionRate = v }
            }

            paramSlider("Density", value: track.density) { v in
                viewModel.updateTrack(at: trackIndex) { $0.density = v }
            }

            Divider().background(Color.gray.opacity(0.3))

            HStack(spacing: 8) {
                quickActionButton("Evolve Once") {
                    EvolutionEngine.evolve(track: &viewModel.tracks[trackIndex], scale: viewModel.scale)
                }
                quickActionButton("Mutate All") {
                    EvolutionEngine.randomizeParameters(track: &viewModel.tracks[trackIndex])
                    EvolutionEngine.evolve(track: &viewModel.tracks[trackIndex], scale: viewModel.scale)
                }
            }

            Text("Evolution gradually mutates the pattern while playing.\nHigher rate = more frequent changes.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private var panLabel: String {
        if track.pan < -0.05 { return "L\(Int(abs(track.pan) * 100))" }
        if track.pan > 0.05 { return "R\(Int(track.pan * 100))" }
        return "C"
    }

    private func paramSlider(_ name: String, value: Float, label: String? = nil, onChange: @escaping (Float) -> Void) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text(label ?? "\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(track.voiceType.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(track.voiceType.color.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(value), height: 6)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let v = Float(drag.location.x / geo.size.width)
                            onChange(max(0, min(1, v)))
                        }
                )
            }
            .frame(height: 6)
        }
    }

    private func quickActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(track.voiceType.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(track.voiceType.color.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
