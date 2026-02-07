import SwiftUI

/// Main content view with polyrhythm visualizer, track list, and transport controls.
struct ContentView: View {
    @StateObject private var viewModel = SessionViewModel()

    @State private var viewMode: ViewMode = .hybrid

    enum ViewMode: String, CaseIterable {
        case visualizer = "Rings"
        case tracks = "Tracks"
        case hybrid = "Hybrid"
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Main content
                switch viewMode {
                case .visualizer:
                    visualizerOnly
                case .tracks:
                    trackListOnly
                case .hybrid:
                    hybridView
                }

                // Transport
                TransportBarView(viewModel: viewModel)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showTrackEditor) {
            if let idx = viewModel.selectedTrackIndex {
                TrackEditorView(viewModel: viewModel, trackIndex: idx)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("POLYRHYTHM")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)

                Text("\(viewModel.scale.rawValue) / \(viewModel.rootNoteName)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.6))
            }

            Spacer()

            // View mode switcher
            HStack(spacing: 0) {
                ForEach(ViewMode.allCases, id: \.rawValue) { mode in
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode } }) {
                        Text(mode.rawValue)
                            .font(.system(size: 10, weight: viewMode == mode ? .bold : .regular, design: .monospaced))
                            .foregroundColor(viewMode == mode ? .white : .gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                viewMode == mode ? Color.white.opacity(0.1) : Color.clear
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Capsule().fill(Color.white.opacity(0.05)))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.95))
    }

    // MARK: - View Modes

    private var visualizerOnly: some View {
        PolyrhythmVisualizerView(
            tracks: viewModel.tracks,
            currentSteps: viewModel.currentSteps,
            isPlaying: viewModel.isPlaying
        )
    }

    private var trackListOnly: some View {
        trackList
    }

    private var hybridView: some View {
        VStack(spacing: 0) {
            // Compact visualizer
            PolyrhythmVisualizerView(
                tracks: viewModel.tracks,
                currentSteps: viewModel.currentSteps,
                isPlaying: viewModel.isPlaying
            )
            .frame(height: 250)

            Divider().background(Color.gray.opacity(0.2))

            // Track list
            trackList
        }
    }

    private var trackList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(
                        track: track,
                        currentStep: viewModel.currentSteps[track.id],
                        isSelected: viewModel.selectedTrackIndex == index,
                        onTap: {
                            viewModel.selectedTrackIndex = index
                            viewModel.showTrackEditor = true
                        },
                        onMuteToggle: {
                            viewModel.updateTrack(at: index) { $0.isMuted.toggle() }
                        },
                        onStepToggle: { stepIndex in
                            viewModel.updateTrack(at: index) { $0.steps[stepIndex].isActive.toggle() }
                        }
                    )
                }

                // Delete track buttons (swipe-like)
                if let selectedIndex = viewModel.selectedTrackIndex, selectedIndex < viewModel.tracks.count {
                    Button(action: { viewModel.removeTrack(at: selectedIndex) }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove \(viewModel.tracks[selectedIndex].name)")
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red.opacity(0.7))
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
    }
}
