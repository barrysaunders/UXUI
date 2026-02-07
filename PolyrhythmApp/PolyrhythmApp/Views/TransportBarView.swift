import SwiftUI

/// Bottom transport bar with play/stop, BPM, and global controls.
struct TransportBarView: View {
    @ObservedObject var viewModel: SessionViewModel

    @State private var showGlobalSettings = false

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color.gray.opacity(0.3))

            HStack(spacing: 16) {
                // Play/Stop
                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(viewModel.isPlaying ? .red : .green)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                // BPM
                VStack(spacing: 2) {
                    Text("BPM")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.gray)

                    HStack(spacing: 6) {
                        Button(action: { viewModel.bpm = max(40, viewModel.bpm - 5) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(viewModel.bpm))")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 40)

                        Button(action: { viewModel.bpm = min(300, viewModel.bpm + 5) }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Evolution toggle
                Button(action: { viewModel.toggleEvolution() }) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16))
                        Text("Evolve")
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(viewModel.isEvolving ? .green : .gray)
                }
                .buttonStyle(.plain)

                // Dice - randomize
                Menu {
                    Button("Smart Patterns") { viewModel.smartRandomize() }
                    Button("Random Patterns") { viewModel.randomizeAll() }
                    Button("Randomize Everything") { viewModel.randomizeEverything() }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 16))
                        Text("Random")
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(.orange)
                }

                // Settings
                Button(action: { showGlobalSettings.toggle() }) {
                    VStack(spacing: 2) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16))
                        Text("Global")
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.95))
        }
        .sheet(isPresented: $showGlobalSettings) {
            GlobalSettingsView(viewModel: viewModel)
        }
    }
}
