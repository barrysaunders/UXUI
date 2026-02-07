import SwiftUI

/// Bottom transport bar with play/stop, BPM, and global controls.
/// Adapts spacing and sizing for iPad.
struct TransportBarView: View {
    @ObservedObject var viewModel: SessionViewModel

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var showGlobalSettings = false

    private var isWide: Bool { horizontalSizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color.gray.opacity(0.3))

            HStack(spacing: isWide ? 28 : 16) {
                // Play/Stop
                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: isWide ? 28 : 22))
                        .foregroundColor(viewModel.isPlaying ? .red : .green)
                        .frame(width: isWide ? 56 : 44, height: isWide ? 56 : 44)
                }
                .buttonStyle(.plain)

                // BPM
                VStack(spacing: 2) {
                    Text("BPM")
                        .font(.system(size: isWide ? 10 : 8, design: .monospaced))
                        .foregroundColor(.gray)

                    HStack(spacing: isWide ? 10 : 6) {
                        Button(action: { viewModel.bpm = max(40, viewModel.bpm - 5) }) {
                            Image(systemName: "minus")
                                .font(.system(size: isWide ? 13 : 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(viewModel.bpm))")
                            .font(.system(size: isWide ? 20 : 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: isWide ? 50 : 40)

                        Button(action: { viewModel.bpm = min(300, viewModel.bpm + 5) }) {
                            Image(systemName: "plus")
                                .font(.system(size: isWide ? 13 : 10))
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
                            .font(.system(size: isWide ? 20 : 16))
                        Text("Evolve")
                            .font(.system(size: isWide ? 10 : 8, design: .monospaced))
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
                            .font(.system(size: isWide ? 20 : 16))
                        Text("Random")
                            .font(.system(size: isWide ? 10 : 8, design: .monospaced))
                    }
                    .foregroundColor(.orange)
                }

                // Settings
                Button(action: { showGlobalSettings.toggle() }) {
                    VStack(spacing: 2) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: isWide ? 20 : 16))
                        Text("Global")
                            .font(.system(size: isWide ? 10 : 8, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, isWide ? 32 : 16)
            .padding(.vertical, isWide ? 12 : 8)
            .background(Color.black.opacity(0.95))
        }
        .sheet(isPresented: $showGlobalSettings) {
            GlobalSettingsView(viewModel: viewModel)
        }
    }
}
