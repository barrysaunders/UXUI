import Foundation
import SwiftUI

// MARK: - Voice Type

enum VoiceType: String, CaseIterable, Codable, Identifiable {
    case kick = "Kick"
    case snare = "Snare"
    case hihat = "Hi-Hat"
    case bass = "Bass"
    case lead = "Lead"
    case pad = "Pad"
    case perc = "Perc"
    case acid = "Acid"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .kick:  return Color(red: 1.0, green: 0.3, blue: 0.3)
        case .snare: return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .hihat: return Color(red: 1.0, green: 1.0, blue: 0.3)
        case .bass:  return Color(red: 0.3, green: 0.5, blue: 1.0)
        case .lead:  return Color(red: 0.7, green: 0.3, blue: 1.0)
        case .pad:   return Color(red: 0.3, green: 0.9, blue: 0.7)
        case .perc:  return Color(red: 1.0, green: 0.5, blue: 0.7)
        case .acid:  return Color(red: 0.0, green: 1.0, blue: 0.5)
        }
    }

    var defaultSteps: Int {
        switch self {
        case .kick:  return 4
        case .snare: return 8
        case .hihat: return 6
        case .bass:  return 5
        case .lead:  return 7
        case .pad:   return 3
        case .perc:  return 9
        case .acid:  return 11
        }
    }

    var icon: String {
        switch self {
        case .kick:  return "circle.fill"
        case .snare: return "burst.fill"
        case .hihat: return "triangle.fill"
        case .bass:  return "waveform.path"
        case .lead:  return "waveform"
        case .pad:   return "cloud.fill"
        case .perc:  return "star.fill"
        case .acid:  return "bolt.fill"
        }
    }
}

// MARK: - Scale

enum Scale: String, CaseIterable, Codable, Identifiable {
    case chromatic = "Chromatic"
    case major = "Major"
    case minor = "Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case mixolydian = "Mixolydian"
    case pentatonicMajor = "Pentatonic Maj"
    case pentatonicMinor = "Pentatonic Min"
    case blues = "Blues"
    case wholeNote = "Whole Tone"
    case japanese = "Japanese"

    var id: String { rawValue }

    /// Semitone intervals from root
    var intervals: [Int] {
        switch self {
        case .chromatic:       return [0,1,2,3,4,5,6,7,8,9,10,11]
        case .major:           return [0,2,4,5,7,9,11]
        case .minor:           return [0,2,3,5,7,8,10]
        case .dorian:          return [0,2,3,5,7,9,10]
        case .phrygian:        return [0,1,3,5,7,8,10]
        case .mixolydian:      return [0,2,4,5,7,9,10]
        case .pentatonicMajor: return [0,2,4,7,9]
        case .pentatonicMinor: return [0,3,5,7,10]
        case .blues:           return [0,3,5,6,7,10]
        case .wholeNote:       return [0,2,4,6,8,10]
        case .japanese:        return [0,1,5,7,8]
        }
    }

    func noteInScale(degree: Int, rootMIDI: Int) -> Int {
        let octave = degree / intervals.count
        let index = ((degree % intervals.count) + intervals.count) % intervals.count
        return rootMIDI + octave * 12 + intervals[index]
    }
}

// MARK: - Step

struct Step: Codable, Identifiable {
    let id: UUID
    var isActive: Bool
    var velocity: Float       // 0.0 - 1.0
    var note: Int             // scale degree (for melodic voices)
    var paramMod: Float       // -1.0 to 1.0 per-step param modulation

    init(isActive: Bool = false, velocity: Float = 0.8, note: Int = 0, paramMod: Float = 0.0) {
        self.id = UUID()
        self.isActive = isActive
        self.velocity = velocity
        self.note = note
        self.paramMod = paramMod
    }
}

// MARK: - Track

struct Track: Codable, Identifiable {
    let id: UUID
    var name: String
    var voiceType: VoiceType
    var steps: [Step]
    var stepCount: Int { steps.count }
    var isMuted: Bool
    var volume: Float         // 0.0 - 1.0
    var pan: Float            // -1.0 to 1.0

    // Synth parameters
    var filterCutoff: Float   // 0.0 - 1.0 (maps to Hz)
    var filterResonance: Float // 0.0 - 1.0
    var attack: Float         // 0.0 - 1.0 (maps to seconds)
    var decay: Float          // 0.0 - 1.0
    var sustain: Float        // 0.0 - 1.0
    var release: Float        // 0.0 - 1.0
    var reverbSend: Float     // 0.0 - 1.0
    var delaySend: Float      // 0.0 - 1.0
    var pitchOffset: Int      // semitones

    // Evolution
    var evolutionRate: Float  // 0.0 - 1.0 how much this track evolves
    var density: Float        // 0.0 - 1.0 probability of steps being active

    var currentStep: Int = 0

    init(voiceType: VoiceType, stepCount: Int? = nil) {
        self.id = UUID()
        self.name = voiceType.rawValue
        self.voiceType = voiceType
        self.isMuted = false
        self.volume = 0.7
        self.pan = 0.0
        self.filterCutoff = 0.7
        self.filterResonance = 0.3
        self.attack = 0.01
        self.decay = 0.3
        self.sustain = 0.5
        self.release = 0.3
        self.reverbSend = 0.2
        self.delaySend = 0.1
        self.pitchOffset = 0
        self.evolutionRate = 0.3
        self.density = 0.5

        let count = stepCount ?? voiceType.defaultSteps
        self.steps = (0..<count).map { i in
            Step(isActive: false, velocity: 0.8, note: i % 5)
        }
    }

    mutating func setStepCount(_ count: Int) {
        let clamped = max(2, min(32, count))
        if clamped > steps.count {
            for i in steps.count..<clamped {
                steps.append(Step(isActive: false, velocity: 0.8, note: i % 5))
            }
        } else if clamped < steps.count {
            steps = Array(steps.prefix(clamped))
        }
        if currentStep >= clamped { currentStep = 0 }
    }

    mutating func advanceStep() {
        currentStep = (currentStep + 1) % steps.count
    }
}

// MARK: - Preset

struct Preset: Codable, Identifiable {
    let id: UUID
    var name: String
    var bpm: Double
    var scale: Scale
    var rootNote: Int
    var tracks: [Track]
    var masterReverb: Float
    var masterDelay: Float
    var swingAmount: Float

    init(name: String, bpm: Double = 120, scale: Scale = .pentatonicMinor, rootNote: Int = 36) {
        self.id = UUID()
        self.name = name
        self.bpm = bpm
        self.scale = scale
        self.rootNote = rootNote
        self.tracks = []
        self.masterReverb = 0.3
        self.masterDelay = 0.2
        self.swingAmount = 0.0
    }
}
