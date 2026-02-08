import Foundation

/// Generates evolving musical patterns through probabilistic mutation.
/// Can randomize entire tracks or gradually evolve them over time.
struct EvolutionEngine {

    // MARK: - Full Randomization

    /// Generate a completely random pattern for a track
    static func randomize(track: inout Track, scale: Scale) {
        let density = track.density

        for i in track.steps.indices {
            track.steps[i].isActive = Float.random(in: 0...1) < density
            track.steps[i].velocity = Float.random(in: 0.4...0.85)
            track.steps[i].note = Int.random(in: 0..<scale.intervals.count * 2)
            track.steps[i].paramMod = Float.random(in: -0.3...0.3)
        }

        // Ensure at least one step is active
        if !track.steps.contains(where: { $0.isActive }) {
            let idx = Int.random(in: 0..<track.steps.count)
            track.steps[idx].isActive = true
        }
    }

    /// Randomize all tracks
    static func randomizeAll(tracks: inout [Track], scale: Scale) {
        for i in tracks.indices {
            randomize(track: &tracks[i], scale: scale)
        }
    }

    // MARK: - Euclidean Rhythms

    /// Generate a Euclidean rhythm pattern
    static func euclidean(steps: Int, pulses: Int) -> [Bool] {
        guard steps > 0, pulses > 0 else { return Array(repeating: false, count: max(steps, 1)) }
        let clampedPulses = min(pulses, steps)

        var pattern = Array(repeating: false, count: steps)
        for i in 0..<steps {
            // Bresenham-style euclidean distribution
            if (i * clampedPulses) % steps < clampedPulses {
                pattern[i] = true
            }
        }
        return pattern
    }

    /// Apply euclidean rhythm to a track
    static func applyEuclidean(track: inout Track, pulses: Int, scale: Scale) {
        let pattern = euclidean(steps: track.steps.count, pulses: pulses)
        for i in track.steps.indices {
            track.steps[i].isActive = pattern[i]
            track.steps[i].velocity = pattern[i] ? Float.random(in: 0.6...1.0) : 0.8
            track.steps[i].note = Int.random(in: 0..<scale.intervals.count * 2)
        }
    }

    // MARK: - Evolution (Gradual Mutation)

    /// Evolve a track by slightly mutating its pattern
    static func evolve(track: inout Track, scale: Scale) {
        let rate = track.evolutionRate

        for i in track.steps.indices {
            // Probability of mutation scales with evolution rate
            let mutationChance = rate * 0.3

            if Float.random(in: 0...1) < mutationChance {
                // Toggle step on/off
                track.steps[i].isActive.toggle()
            }

            if track.steps[i].isActive && Float.random(in: 0...1) < mutationChance {
                // Shift velocity slightly
                let shift = Float.random(in: -0.15...0.15)
                track.steps[i].velocity = max(0.1, min(1.0, track.steps[i].velocity + shift))
            }

            if Float.random(in: 0...1) < mutationChance * 0.5 {
                // Shift note by one scale degree
                let shift = Int.random(in: -2...2)
                track.steps[i].note = max(0, min(scale.intervals.count * 3, track.steps[i].note + shift))
            }

            if Float.random(in: 0...1) < mutationChance * 0.3 {
                // Mutate param mod
                let shift = Float.random(in: -0.2...0.2)
                track.steps[i].paramMod = max(-1.0, min(1.0, track.steps[i].paramMod + shift))
            }
        }

        // Ensure at least one step is active
        if !track.steps.contains(where: { $0.isActive }) {
            let idx = Int.random(in: 0..<track.steps.count)
            track.steps[idx].isActive = true
        }
    }

    /// Evolve all tracks
    static func evolveAll(tracks: inout [Track], scale: Scale) {
        for i in tracks.indices {
            evolve(track: &tracks[i], scale: scale)
        }
    }

    // MARK: - Smart Patterns

    /// Generate musically-informed patterns based on voice type
    static func generateSmart(track: inout Track, scale: Scale) {
        switch track.voiceType {
        case .kick:
            generateSmartKick(track: &track)
        case .snare:
            generateSmartSnare(track: &track)
        case .hihat:
            generateSmartHiHat(track: &track)
        case .bass:
            generateSmartBass(track: &track, scale: scale)
        case .lead:
            generateSmartLead(track: &track, scale: scale)
        case .pad:
            generateSmartPad(track: &track, scale: scale)
        case .perc:
            generateSmartPerc(track: &track)
        case .acid:
            generateSmartAcid(track: &track, scale: scale)
        }
    }

    private static func generateSmartKick(track: inout Track) {
        // Four-on-the-floor variations
        let patterns: [[Bool]] = [
            [true, false, false, false],
            [true, false, true, false],
            [true, false, false, true],
            [true, true, false, false],
        ]
        let chosen = patterns.randomElement()!

        for i in track.steps.indices {
            track.steps[i].isActive = chosen[i % chosen.count]
            track.steps[i].velocity = track.steps[i].isActive ? Float.random(in: 0.7...1.0) : 0.8
        }
    }

    private static func generateSmartSnare(track: inout Track) {
        for i in track.steps.indices {
            let position = Float(i) / Float(track.steps.count)
            // Snares tend to land on offbeats
            let offbeat = (i % 2 == 1)
            let chance: Float = offbeat ? 0.6 : 0.15
            track.steps[i].isActive = Float.random(in: 0...1) < chance
            track.steps[i].velocity = offbeat ? Float.random(in: 0.7...1.0) : Float.random(in: 0.4...0.7)
            _ = position  // used for future enhancements
        }
        // Ensure at least one hit
        if !track.steps.contains(where: { $0.isActive }) {
            let idx = track.steps.count / 2
            if idx < track.steps.count { track.steps[idx].isActive = true }
        }
    }

    private static func generateSmartHiHat(track: inout Track) {
        // Dense rhythmic patterns
        for i in track.steps.indices {
            track.steps[i].isActive = Float.random(in: 0...1) < 0.7
            // Accent pattern
            track.steps[i].velocity = (i % 2 == 0) ? Float.random(in: 0.7...1.0) : Float.random(in: 0.3...0.6)
        }
    }

    private static func generateSmartBass(track: inout Track, scale: Scale) {
        let noteRange = scale.intervals.count
        var currentNote = 0  // root

        for i in track.steps.indices {
            let chance: Float = (i == 0) ? 0.9 : track.density
            track.steps[i].isActive = Float.random(in: 0...1) < chance

            // Step-wise motion with occasional leaps
            if Float.random(in: 0...1) < 0.7 {
                currentNote += Int.random(in: -1...1)
            } else {
                currentNote += Int.random(in: -3...3)
            }
            currentNote = max(0, min(noteRange, currentNote))
            track.steps[i].note = currentNote
            track.steps[i].velocity = (i == 0) ? Float.random(in: 0.8...1.0) : Float.random(in: 0.5...0.9)
        }
    }

    private static func generateSmartLead(track: inout Track, scale: Scale) {
        let noteRange = scale.intervals.count * 2
        var currentNote = scale.intervals.count  // start in middle

        for i in track.steps.indices {
            track.steps[i].isActive = Float.random(in: 0...1) < track.density

            // Melodic motion
            if Float.random(in: 0...1) < 0.6 {
                currentNote += Int.random(in: -2...2)
            } else {
                currentNote += Int.random(in: -4...4)
            }
            currentNote = max(0, min(noteRange, currentNote))
            track.steps[i].note = currentNote
            track.steps[i].velocity = Float.random(in: 0.5...1.0)
            track.steps[i].paramMod = Float.random(in: -0.3...0.3)
        }
    }

    private static func generateSmartPad(track: inout Track, scale: Scale) {
        // Pads: long sustained notes, fewer triggers
        for i in track.steps.indices {
            track.steps[i].isActive = (i == 0) || Float.random(in: 0...1) < 0.2
            track.steps[i].note = Int.random(in: 0..<scale.intervals.count)
            track.steps[i].velocity = Float.random(in: 0.4...0.7)
        }
    }

    private static func generateSmartPerc(track: inout Track) {
        // Polyrhythmic percussion, use euclidean base
        let pulses = Int.random(in: 2...max(3, track.steps.count - 1))
        let pattern = euclidean(steps: track.steps.count, pulses: pulses)
        for i in track.steps.indices {
            track.steps[i].isActive = pattern[i]
            track.steps[i].velocity = Float.random(in: 0.4...1.0)
            track.steps[i].paramMod = Float.random(in: -0.5...0.5)
        }
    }

    private static func generateSmartAcid(track: inout Track, scale: Scale) {
        let noteRange = scale.intervals.count * 2
        var currentNote = 0

        for i in track.steps.indices {
            track.steps[i].isActive = Float.random(in: 0...1) < 0.65

            // 303-style: lots of slides, accents, and octave jumps
            if Float.random(in: 0...1) < 0.3 {
                currentNote += (Float.random(in: 0...1) < 0.5) ? scale.intervals.count : -scale.intervals.count
            } else {
                currentNote += Int.random(in: -2...2)
            }
            currentNote = max(0, min(noteRange, currentNote))
            track.steps[i].note = currentNote
            track.steps[i].velocity = Float.random(in: 0.5...1.0)
            track.steps[i].paramMod = Float.random(in: -0.4...0.4)  // filter sweeps
        }
    }

    // MARK: - Randomize Parameters

    /// Randomize synth parameters for a track
    static func randomizeParameters(track: inout Track) {
        track.filterCutoff = Float.random(in: 0.3...0.85)
        track.filterResonance = Float.random(in: 0.0...0.45)

        switch track.voiceType {
        case .kick, .snare, .hihat, .perc:
            track.attack = Float.random(in: 0.0...0.05)
            track.decay = Float.random(in: 0.1...0.4)
            track.sustain = Float.random(in: 0.0...0.2)
            track.release = Float.random(in: 0.05...0.25)
        case .bass, .acid:
            track.attack = Float.random(in: 0.0...0.08)
            track.decay = Float.random(in: 0.1...0.5)
            track.sustain = Float.random(in: 0.2...0.6)
            track.release = Float.random(in: 0.1...0.3)
        case .lead:
            track.attack = Float.random(in: 0.01...0.15)
            track.decay = Float.random(in: 0.1...0.4)
            track.sustain = Float.random(in: 0.3...0.7)
            track.release = Float.random(in: 0.1...0.4)
        case .pad:
            track.attack = Float.random(in: 0.2...0.6)
            track.decay = Float.random(in: 0.3...0.7)
            track.sustain = Float.random(in: 0.4...0.8)
            track.release = Float.random(in: 0.3...0.6)
        }

        track.reverbSend = Float.random(in: 0.0...0.4)
        track.delaySend = Float.random(in: 0.0...0.35)
        track.volume = Float.random(in: 0.5...0.8)
    }

    /// Completely randomize everything
    static func randomizeEverything(tracks: inout [Track], scale: Scale) {
        for i in tracks.indices {
            randomizeParameters(track: &tracks[i])
            generateSmart(track: &tracks[i], scale: scale)
        }
    }
}
