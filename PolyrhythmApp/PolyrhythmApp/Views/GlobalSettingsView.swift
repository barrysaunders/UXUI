import SwiftUI

/// Full-screen settings for global parameters: scale, root note, master effects, presets.
/// On iPad, constrains content width for readability.
struct GlobalSettingsView: View {
    @ObservedObject var viewModel: SessionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var presetName = ""

    private var isWide: Bool { horizontalSizeClass == .regular }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    globalSection
                    effectsSection
                    trackManagementSection
                    presetSection
                }
                .padding(isWide ? 32 : 16)
                .frame(maxWidth: isWide ? 700 : .infinity)
                .frame(maxWidth: .infinity) // center within scroll
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
        .navigationViewStyle(.stack)
    }

    // MARK: - Global

    private var globalSection: some View {
        VStack(alignment: .leading, spacing: isWide ? 16 : 12) {
            sectionHeader("Musical")

            HStack {
                Text("Scale")
                    .font(.system(size: isWide ? 14 : 12, design: .monospaced))
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

            HStack {
                Text("Root")
                    .font(.system(size: isWide ? 14 : 12, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()

                Button(action: { viewModel.rootNote = max(24, viewModel.rootNote - 1) }) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: isWide ? 18 : 14))
                        .foregroundColor(.white.opacity(0.5))
                }

                Text(viewModel.rootNoteName)
                    .font(.system(size: isWide ? 16 : 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .frame(width: isWide ? 60 : 50)

                Button(action: { viewModel.rootNote = min(72, viewModel.rootNote + 1) }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: isWide ? 18 : 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            settingsSlider("BPM", value: $viewModel.bpm, range: 40...300, step: 1, format: { "\(Int($0))" })
            settingsSlider("Swing", value: Binding(
                get: { Double(viewModel.swingAmount) },
                set: { viewModel.swingAmount = Float($0) }
            ), range: 0...1, step: 0.01, format: { "\(Int($0 * 100))%" })
            settingsSlider("Evolution Speed", value: $viewModel.evolutionInterval, range: 1...16, step: 0.5, format: { "\(String(format: "%.1f", $0)) beats" })
        }
        .padding(isWide ? 20 : 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Effects

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: isWide ? 16 : 12) {
            sectionHeader("Master Effects")

            settingsSlider("Master Volume", value: Binding(
                get: { Double(viewModel.audioEngine.masterVolume) },
                set: { viewModel.audioEngine.masterVolume = Float($0) }
            ), range: 0...1, step: 0.01, format: { "\(Int($0 * 100))%" }, tintColor: .purple)

            settingsSlider("Reverb", value: Binding(
                get: { Double(viewModel.audioEngine.reverbMix) },
                set: { viewModel.audioEngine.reverbMix = Float($0) }
            ), range: 0...1, step: 0.01, format: { "\(Int($0 * 100))%" }, tintColor: .purple)

            settingsSlider("Delay", value: Binding(
                get: { Double(viewModel.audioEngine.delayMix) },
                set: { viewModel.audioEngine.delayMix = Float($0) }
            ), range: 0...1, step: 0.01, format: { "\(Int($0 * 100))%" }, tintColor: .purple)
        }
        .padding(isWide ? 20 : 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Track Management

    private var trackManagementSection: some View {
        VStack(alignment: .leading, spacing: isWide ? 16 : 12) {
            sectionHeader("Add Track")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isWide ? 4 : 4), spacing: isWide ? 12 : 8) {
                ForEach(VoiceType.allCases) { voice in
                    Button(action: {
                        viewModel.addTrack(voiceType: voice)
                        EvolutionEngine.generateSmart(track: &viewModel.tracks[viewModel.tracks.count - 1], scale: viewModel.scale)
                    }) {
                        VStack(spacing: isWide ? 6 : 4) {
                            Image(systemName: voice.icon)
                                .font(.system(size: isWide ? 20 : 16))
                            Text(voice.rawValue)
                                .font(.system(size: isWide ? 11 : 9, design: .monospaced))
                        }
                        .foregroundColor(voice.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isWide ? 14 : 10)
                        .background(
                            RoundedRectangle(cornerRadius: isWide ? 10 : 8)
                                .stroke(voice.color.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(isWide ? 20 : 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Presets

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: isWide ? 16 : 12) {
            sectionHeader("Presets")

            HStack {
                TextField("Preset name", text: $presetName)
                    .font(.system(size: isWide ? 16 : 14, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    guard !presetName.isEmpty else { return }
                    viewModel.savePreset(name: presetName)
                }
                .font(.system(size: isWide ? 16 : 14))
                .foregroundColor(.green)
            }

            ForEach(viewModel.presets) { preset in
                Button(action: { viewModel.loadPreset(preset) }) {
                    HStack {
                        Text(preset.name)
                            .font(.system(size: isWide ? 15 : 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(Int(preset.bpm)) BPM")
                            .font(.system(size: isWide ? 13 : 11, design: .monospaced))
                            .foregroundColor(.gray)

                        Text("\(preset.tracks.count) tracks")
                            .font(.system(size: isWide ? 13 : 11, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, isWide ? 8 : 6)
                }
                .buttonStyle(.plain)
            }

            if viewModel.presets.isEmpty {
                Text("No saved presets")
                    .font(.system(size: isWide ? 13 : 11, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(isWide ? 20 : 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: isWide ? 12 : 10, weight: .bold, design: .monospaced))
            .foregroundColor(.gray)
            .tracking(2)
    }

    private func settingsSlider(_ name: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: @escaping (Double) -> String, tintColor: Color = .cyan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: isWide ? 14 : 12, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.system(size: isWide ? 16 : 14, weight: .bold, design: .monospaced))
                    .foregroundColor(tintColor)
            }
            Slider(value: value, in: range, step: step)
                .tint(tintColor)
        }
    }
}
