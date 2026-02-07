import SwiftUI

/// Full-screen settings for global parameters: scale, root note, master effects, presets.
struct GlobalSettingsView: View {
    @ObservedObject var viewModel: SessionViewModel
    @Environment(\.dismiss) var dismiss

    @State private var presetName = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    globalSection
                    effectsSection
                    trackManagementSection
                    presetSection
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Global Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Global

    private var globalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Musical")

            // Scale picker
            HStack {
                Text("Scale")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Picker("Scale", selection: $viewModel.scale) {
                    ForEach(Scale.allCases) { scale in
                        Text(scale.rawValue).tag(scale)
                    }
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }

            // Root note
            HStack {
                Text("Root")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()

                Button(action: { viewModel.rootNote = max(24, viewModel.rootNote - 1) }) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.white.opacity(0.5))
                }

                Text(viewModel.rootNoteName)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .frame(width: 50)

                Button(action: { viewModel.rootNote = min(72, viewModel.rootNote + 1) }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // BPM slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("BPM")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(viewModel.bpm))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                Slider(value: $viewModel.bpm, in: 40...300, step: 1)
                    .tint(.cyan)
            }

            // Swing
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Swing")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(viewModel.swingAmount * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                Slider(value: $viewModel.swingAmount, in: 0...1)
                    .tint(.cyan)
            }

            // Evolution interval
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Evolution Speed")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(String(format: "%.1f", viewModel.evolutionInterval)) beats")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                Slider(value: $viewModel.evolutionInterval, in: 1...16, step: 0.5)
                    .tint(.cyan)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Effects

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Master Effects")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Master Volume")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(viewModel.masterVolume * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)
                }
                Slider(value: $viewModel.masterVolume, in: 0...1)
                    .tint(.purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Reverb")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(viewModel.reverbMix * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)
                }
                Slider(value: $viewModel.reverbMix, in: 0...1)
                    .tint(.purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Delay")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(viewModel.delayMix * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)
                }
                Slider(value: $viewModel.delayMix, in: 0...1)
                    .tint(.purple)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Track Management

    private var trackManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Add Track")

            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible())
            ], spacing: 8) {
                ForEach(VoiceType.allCases) { voice in
                    Button(action: {
                        viewModel.addTrack(voiceType: voice)
                        EvolutionEngine.generateSmart(track: &viewModel.tracks[viewModel.tracks.count - 1], scale: viewModel.scale)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: voice.icon)
                                .font(.system(size: 16))
                            Text(voice.rawValue)
                                .font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundColor(voice.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(voice.color.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Presets

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Presets")

            HStack {
                TextField("Preset name", text: $presetName)
                    .font(.system(size: 14, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    guard !presetName.isEmpty else { return }
                    viewModel.savePreset(name: presetName)
                }
                .foregroundColor(.green)
            }

            ForEach(viewModel.presets) { preset in
                Button(action: { viewModel.loadPreset(preset) }) {
                    HStack {
                        Text(preset.name)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(Int(preset.bpm)) BPM")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)

                        Text("\(preset.tracks.count) tracks")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }

            if viewModel.presets.isEmpty {
                Text("No saved presets")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.gray)
            .tracking(2)
    }
}
