import Foundation
import Combine

/// Polyrhythmic sequencer that drives multiple tracks with independent step counts.
/// Uses a high-resolution timer to trigger steps at the correct musical time.
final class Sequencer: ObservableObject {
    @Published var isPlaying = false
    @Published var bpm: Double = 120.0 {
        didSet { recalculateTiming() }
    }
    @Published var swingAmount: Float = 0.0
    @Published var globalStep: Int = 0

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.polyrhythm.sequencer", qos: .userInteractive)

    // Tracks and their synths - accessed from both main and timer threads
    private var trackSynths: [(track: Track, synth: Synthesizer)] = []
    private let trackLock = NSLock()

    // Timing
    private var tickCount: Int = 0
    private let ticksPerStep = 24  // sub-step resolution for swing
    private var tickInterval: TimeInterval = 0.01

    // Callback to update UI
    var onStepAdvanced: ((UUID, Int) -> Void)?
    var onGlobalBeat: ((Int) -> Void)?

    // Scale info
    var scale: Scale = .pentatonicMinor
    var rootNote: Int = 36  // MIDI note C2

    init() {
        recalculateTiming()
    }

    // MARK: - Configuration

    func setTracks(_ tracks: [Track], synths: [UUID: Synthesizer]) {
        let newTrackSynths = tracks.compactMap { track -> (track: Track, synth: Synthesizer)? in
            guard let synth = synths[track.id] else { return nil }
            return (track, synth)
        }
        trackLock.lock()
        trackSynths = newTrackSynths
        trackLock.unlock()
    }

    func updateTrack(_ track: Track) {
        trackLock.lock()
        if let index = trackSynths.firstIndex(where: { $0.track.id == track.id }) {
            let synth = trackSynths[index].synth
            trackSynths[index] = (track, synth)

            synth.voiceType = track.voiceType
            synth.filterCutoff = track.filterCutoff
            synth.filterResonance = track.filterResonance
            synth.attack = track.attack
            synth.decay = track.decay
            synth.sustain = track.sustain
            synth.release = track.release
        }
        trackLock.unlock()
    }

    private func recalculateTiming() {
        // Time per tick: BPM defines quarter notes, each step = 1 sixteenth note
        // ticksPerStep ticks per step gives us swing resolution
        let stepsPerSecond = (bpm / 60.0) * 4.0  // 16th notes per second
        tickInterval = 1.0 / (stepsPerSecond * Double(ticksPerStep))
    }

    // MARK: - Transport

    func start() {
        guard !isPlaying else { return }
        isPlaying = true
        tickCount = 0
        globalStep = 0

        // Reset all track positions
        trackLock.lock()
        for i in trackSynths.indices {
            trackSynths[i].track.currentStep = 0
        }
        trackLock.unlock()

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: tickInterval)
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        isPlaying = false
        timer?.cancel()
        timer = nil

        // Send note-offs
        trackLock.lock()
        let currentTrackSynths = trackSynths
        trackLock.unlock()
        for (_, synth) in currentTrackSynths {
            synth.noteOff()
        }
    }

    func reset() {
        stop()
        tickCount = 0
        globalStep = 0
        trackLock.lock()
        for i in trackSynths.indices {
            trackSynths[i].track.currentStep = 0
        }
        trackLock.unlock()
    }

    // MARK: - Tick

    private func tick() {
        let currentTick = tickCount
        tickCount += 1

        // Snapshot the current tracks under lock
        trackLock.lock()
        let snapshot = trackSynths
        trackLock.unlock()

        // Check if this tick aligns with a step for each track
        for i in snapshot.indices {
            let track = snapshot[i].track
            guard !track.isMuted else { continue }

            let synth = snapshot[i].synth

            // Each track has its own step division based on stepCount
            // The "cycle length" for this track in ticks
            let cycleLength = track.stepCount * ticksPerStep

            let tickInCycle = currentTick % cycleLength
            let stepInCycle = tickInCycle / ticksPerStep

            // Apply swing: delay even-numbered steps slightly
            let isSwungStep = stepInCycle % 2 == 1
            let swingOffset = isSwungStep ? Int(Float(ticksPerStep) * swingAmount * 0.33) : 0
            let tickInStep = tickInCycle % ticksPerStep

            if tickInStep == swingOffset {
                // Trigger step
                let step = track.steps[stepInCycle]

                if step.isActive {
                    // Calculate frequency
                    let midiNote: Int
                    if track.voiceType == .kick || track.voiceType == .snare ||
                       track.voiceType == .hihat || track.voiceType == .perc {
                        midiNote = rootNote + track.pitchOffset
                    } else {
                        midiNote = scale.noteInScale(degree: step.note, rootMIDI: rootNote + track.pitchOffset)
                    }
                    let frequency = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)

                    synth.paramMod = step.paramMod
                    synth.noteOn(frequency: frequency, velocity: step.velocity)
                }

                // Notify UI
                DispatchQueue.main.async { [weak self] in
                    self?.onStepAdvanced?(track.id, stepInCycle)
                }
            }
        }

        // Global beat counter (based on smallest tick division)
        if currentTick % ticksPerStep == 0 {
            let newStep = currentTick / ticksPerStep
            DispatchQueue.main.async { [weak self] in
                self?.globalStep = newStep
                self?.onGlobalBeat?(newStep)
            }
        }
    }
}
