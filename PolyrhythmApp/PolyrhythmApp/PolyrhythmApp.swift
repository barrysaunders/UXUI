import SwiftUI

// MARK: - Focused Value for cross-scene keyboard shortcuts

struct FocusedSessionKey: FocusedValueKey {
    typealias Value = SessionViewModel
}

extension FocusedValues {
    var session: SessionViewModel? {
        get { self[FocusedSessionKey.self] }
        set { self[FocusedSessionKey.self] = newValue }
    }
}

// MARK: - Transport Commands (Mac menu bar + keyboard shortcuts)

struct TransportCommands: Commands {
    @FocusedValue(\.session) var session

    var body: some Commands {
        CommandMenu("Transport") {
            Button(session?.isPlaying == true ? "Stop" : "Play") {
                session?.togglePlayback()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Evolve Toggle") {
                session?.toggleEvolution()
            }
            .keyboardShortcut("e", modifiers: .command)

            Divider()

            Button("Smart Randomize") {
                session?.smartRandomize()
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Randomize Everything") {
                session?.randomizeEverything()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Increase BPM") {
                if let s = session { s.bpm = min(300, s.bpm + 5) }
            }
            .keyboardShortcut("]", modifiers: .command)

            Button("Decrease BPM") {
                if let s = session { s.bpm = max(40, s.bpm - 5) }
            }
            .keyboardShortcut("[", modifiers: .command)
        }
    }
}

// MARK: - App

@main
struct PolyrhythmApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(iOS)
        .defaultSize(width: 1024, height: 768)
        #endif
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 1200, height: 800)
        #endif
        .commands { TransportCommands() }
    }
}
