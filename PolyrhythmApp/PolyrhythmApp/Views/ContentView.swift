import SwiftUI

/// Main content view with polyrhythm visualizer, track list, and transport controls.
/// Adapts layout for iPhone (stacked) and iPad (side-by-side in landscape).
struct ContentView: View {
    @StateObject private var viewModel = SessionViewModel()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State private var viewMode: ViewMode = .hybrid

    enum ViewMode: String, CaseIterable {
        case visualizer = "Rings"
        case tracks = "Tracks"
        case hybrid = "Hybrid"
    }

    /// True when we have enough width for side-by-side (iPad landscape, or any regular width)
    private var isWideLayout: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if isWideLayout {
                    iPadLayout
                } else {
                    iPhoneLayout
                }

                TransportBarView(viewModel: viewModel)
            }
        }
        .preferredColorScheme(.dark)
        .focusedSceneValue(\.session, viewModel)
        .sheet(isPresented: $viewModel.showTrackEditor) {
            if let idx = viewModel.selectedTrackIndex {
                TrackEditorView(viewModel: viewModel, trackIndex: idx)
                    .presentationDetents(isWideLayout ? [.large] : [.medium, .large])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - iPhone Layout (stacked, as before)

    private var iPhoneLayout: some View {
        Group {
            switch viewMode {
            case .visualizer:
                visualizerView
            case .tracks:
                trackList
            case .hybrid:
                VStack(spacing: 0) {
                    visualizerView
                        .frame(height: 250)
                    Divider().background(Color.gray.opacity(0.2))
                    trackList
                }
            }
        }
    }

    // MARK: - iPad Layout (side-by-side)

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // Left: Visualizer (always visible on iPad)
            visualizerView
                .frame(minWidth: 300)

            Divider().background(Color.gray.opacity(0.2))

            // Right: Track list
            trackList
                .frame(minWidth: 320, idealWidth: 420, maxWidth: 600)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("POLYRHYTHM")
                    .font(.system(size: isWideLayout ? 18 : 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)

                Text("\(viewModel.scale.rawValue) / \(viewModel.rootNoteName)")
                    .font(.system(size: isWideLayout ? 12 : 10, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.6))
            }

            Spacer()

            // View mode switcher (only shown on compact/iPhone where we stack)
            if !isWideLayout {
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
        }
        .padding(.horizontal, isWideLayout ? 24 : 16)
        .padding(.vertical, isWideLayout ? 12 : 8)
        .background(Color.black.opacity(0.95))
    }

    // MARK: - Shared Subviews

    private var visualizerView: some View {
        PolyrhythmVisualizerView(
            tracks: viewModel.tracks,
            currentSteps: viewModel.currentSteps,
            isPlaying: viewModel.isPlaying
        )
    }

    private var trackList: some View {
        ScrollView {
            LazyVStack(spacing: isWideLayout ? 6 : 4) {
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

                if let selectedIndex = viewModel.selectedTrackIndex, selectedIndex < viewModel.tracks.count {
                    Button(action: { viewModel.removeTrack(at: selectedIndex) }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove \(viewModel.tracks[selectedIndex].name)")
                        }
                        .font(.system(size: isWideLayout ? 13 : 11, design: .monospaced))
                        .foregroundColor(.red.opacity(0.7))
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, isWideLayout ? 8 : 0)
        }
    }
}
