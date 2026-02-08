import Foundation
import Combine
import SwiftUI

/// Central view model coordinating the audio engine, sequencer, and UI state.
@MainActor
final class SessionViewModel: ObservableObject {
    // Audio
    let audioEngine = AudioEngine()
    let sequencer = Sequencer()
    private var synths: [UUID: Synthesizer] = [:]

    // State
    @Published var tracks: [Track] = []
    @Published var isPlaying = false
    @Published var bpm: Double = 120.0 {
        didSet {
            sequencer.bpm = bpm
            audioEngine.updateDelayTime(bpm: bpm)
        }
    }
    @Published var scale: Scale = .pentatonicMinor {
        didSet { sequencer.scale = scale }
    }
    @Published var rootNote: Int = 36 {
        didSet { sequencer.rootNote = rootNote }
    }
    @Published var swingAmount: Float = 0.0 {
        didSet { sequencer.swingAmount = swingAmount }
    }

    // Master effects (proxied to audioEngine)
    @Published var masterVolume: Float = 0.8 {
        didSet { audioEngine.masterVolume = masterVolume }
    }
    @Published var reverbMix: Float = 0.3 {
        didSet { audioEngine.reverbMix = reverbMix }
    }
    @Published var delayMix: Float = 0.2 {
        didSet { audioEngine.delayMix = delayMix }
    }

    @Published var currentSteps: [UUID: Int] = [:]
    @Published var selectedTrackIndex: Int? = nil
    @Published var showTrackEditor = false
    @Published var isEvolving = false

    // Evolution timer
    private var evolutionTimer: Timer?
    @Published var evolutionInterval: Double = 4.0 // beats between evolutions

    // Presets
    @Published var presets: [Preset] = []
    @Published var currentPresetName: String = "Untitled"

    var selectedTrack: Track? {
        guard let idx = selectedTrackIndex, idx < tracks.count else { return nil }
        return tracks[idx]
    }

    init() {
        // Initialize audio engine values
        masterVolume = audioEngine.masterVolume
        reverbMix = audioEngine.reverbMix
        delayMix = audioEngine.delayMix
        
        setupSequencerCallbacks()
        loadDefaultSession()
    }

    // MARK: - Setup

    private func setupSequencerCallbacks() {
        sequencer.onStepAdvanced = { [weak self] trackId, step in
            Task { @MainActor in
                self?.currentSteps[trackId] = step
            }
        }
        sequencer.scale = scale
        sequencer.rootNote = rootNote
    }

    private func loadDefaultSession() {
        // Create a default polyrhythmic setup
        addTrack(voiceType: .kick, steps: 4)
        addTrack(voiceType: .hihat, steps: 6)
        addTrack(voiceType: .snare, steps: 8)
        addTrack(voiceType: .bass, steps: 5)
        addTrack(voiceType: .lead, steps: 7)
        addTrack(voiceType: .pad, steps: 3)

        // Generate smart patterns for all tracks
        var updated = tracks
        for i in updated.indices {
            EvolutionEngine.generateSmart(track: &updated[i], scale: scale)
        }
        tracks = updated

        syncAllTrackParameters()
    }

    // MARK: - Track Management

    func addTrack(voiceType: VoiceType, steps: Int? = nil) {
        var track = Track(voiceType: voiceType, stepCount: steps)
        track.setStepCount(steps ?? voiceType.defaultSteps)

        let synth = audioEngine.addTrack(for: track)
        synths[track.id] = synth
        tracks.append(track)
    }

    func removeTrack(at index: Int) {
        guard index < tracks.count else { return }
        let track = tracks[index]
        audioEngine.removeTrack(id: track.id)
        synths.removeValue(forKey: track.id)
        tracks.remove(at: index)
        currentSteps.removeValue(forKey: track.id)

        if selectedTrackIndex == index {
            selectedTrackIndex = nil
            showTrackEditor = false
        } else if let sel = selectedTrackIndex, sel > index {
            selectedTrackIndex = sel - 1
        }

        syncTracksToSequencer()
    }

    func updateTrack(at index: Int, _ update: (inout Track) -> Void) {
        guard index < tracks.count else { return }
        update(&tracks[index])

        let track = tracks[index]
        audioEngine.updateTrackVolume(id: track.id, volume: track.isMuted ? 0.0 : track.volume)
        audioEngine.updateTrackPan(id: track.id, pan: track.pan)

        if let synth = synths[track.id] {
            synth.voiceType = track.voiceType
            synth.filterCutoff = track.filterCutoff
            synth.filterResonance = track.filterResonance
            synth.attack = track.attack
            synth.decay = track.decay
            synth.sustain = track.sustain
            synth.release = track.release
        }

        sequencer.updateTrack(track)
    }

    // MARK: - Transport

    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    func startPlayback() {
        syncTracksToSequencer()
        audioEngine.start()
        sequencer.start()
        isPlaying = true
    }

    func stopPlayback() {
        sequencer.stop()
        isPlaying = false
        currentSteps = [:]
    }

    private func syncTracksToSequencer() {
        sequencer.setTracks(tracks, synths: synths)
    }

    /// Push all track parameters (filter, ADSR, volume, pan) to their
    /// corresponding Synthesizer objects and AudioEngine mixer nodes.
    /// Must be called after any bulk edit (randomize, evolve, preset load).
    private func syncAllTrackParameters() {
        for track in tracks {
            if let synth = synths[track.id] {
                synth.voiceType = track.voiceType
                synth.filterCutoff = track.filterCutoff
                synth.filterResonance = track.filterResonance
                synth.attack = track.attack
                synth.decay = track.decay
                synth.sustain = track.sustain
                synth.release = track.release
            }
            audioEngine.updateTrackVolume(id: track.id, volume: track.isMuted ? 0.0 : track.volume)
            audioEngine.updateTrackPan(id: track.id, pan: track.pan)
        }
        syncTracksToSequencer()
    }

    // MARK: - Randomization

    func randomizeAll() {
        var updated = tracks
        EvolutionEngine.randomizeAll(tracks: &updated, scale: scale)
        tracks = updated
        syncAllTrackParameters()
    }

    func randomizeTrack(at index: Int) {
        guard index < tracks.count else { return }
        var updated = tracks
        EvolutionEngine.randomize(track: &updated[index], scale: scale)
        tracks = updated
        syncAllTrackParameters()
    }

    func smartRandomize() {
        var updated = tracks
        for i in updated.indices {
            EvolutionEngine.generateSmart(track: &updated[i], scale: scale)
        }
        tracks = updated
        syncAllTrackParameters()
    }

    func randomizeEverything() {
        var updated = tracks
        EvolutionEngine.randomizeEverything(tracks: &updated, scale: scale)
        tracks = updated
        syncAllTrackParameters()
    }

    func euclideanize(trackIndex: Int, pulses: Int) {
        guard trackIndex < tracks.count else { return }
        var updated = tracks
        EvolutionEngine.applyEuclidean(track: &updated[trackIndex], pulses: pulses, scale: scale)
        tracks = updated
        syncAllTrackParameters()
    }

    // MARK: - Evolution

    func toggleEvolution() {
        isEvolving.toggle()
        if isEvolving {
            startEvolution()
        } else {
            stopEvolution()
        }
    }

    private func startEvolution() {
        let interval = (60.0 / bpm) * evolutionInterval
        evolutionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evolveStep()
            }
        }
    }

    private func stopEvolution() {
        evolutionTimer?.invalidate()
        evolutionTimer = nil
    }

    private func evolveStep() {
        var updated = tracks
        EvolutionEngine.evolveAll(tracks: &updated, scale: scale)
        tracks = updated
        syncAllTrackParameters()
    }

    // MARK: - Presets

    func savePreset(name: String) {
        var preset = Preset(name: name, bpm: bpm, scale: scale, rootNote: rootNote)
        preset.tracks = tracks
        preset.masterReverb = reverbMix
        preset.masterDelay = delayMix
        preset.swingAmount = swingAmount

        if let idx = presets.firstIndex(where: { $0.name == name }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }

        currentPresetName = name
    }

    func loadPreset(_ preset: Preset) {
        let wasPlaying = isPlaying
        if wasPlaying { stopPlayback() }

        // Remove existing tracks
        for track in tracks {
            audioEngine.removeTrack(id: track.id)
            synths.removeValue(forKey: track.id)
        }
        tracks.removeAll()
        currentSteps.removeAll()

        // Load preset state
        bpm = preset.bpm
        scale = preset.scale
        rootNote = preset.rootNote
        swingAmount = preset.swingAmount
        reverbMix = preset.masterReverb
        delayMix = preset.masterDelay

        // Recreate tracks
        for var track in preset.tracks {
            let synth = audioEngine.addTrack(for: track)
            synths[track.id] = synth
            track.currentStep = 0
            tracks.append(track)
        }

        currentPresetName = preset.name
        syncTracksToSequencer()

        if wasPlaying { startPlayback() }
    }

    // MARK: - Global Parameters

    var rootNoteNames: [String] {
        ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    }

    var rootNoteName: String {
        let noteIndex = rootNote % 12
        let octave = rootNote / 12 - 1
        return "\(rootNoteNames[noteIndex])\(octave)"
    }
}
