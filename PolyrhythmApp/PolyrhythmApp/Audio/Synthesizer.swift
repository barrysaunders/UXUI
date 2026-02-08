import AVFoundation
import Foundation

/// Lightweight DSP synthesizer that renders audio samples for different voice types.
/// All processing is done in the audio render thread via AVAudioSourceNode.
final class Synthesizer {
    private let sampleRate: Double = 44100.0

    // Oscillator state
    private var phase: Double = 0.0
    private var phase2: Double = 0.0
    private var phase3: Double = 0.0

    // Envelope state
    private var envLevel: Double = 0.0
    private var envStage: EnvStage = .idle
    private var envSamples: Int = 0

    // Filter state
    private var filterBuf0: Double = 0.0
    private var filterBuf1: Double = 0.0

    // Noise state
    private var noiseValue: Double = 0.0
    private var noiseSampleCounter: Int = 0

    // Trigger state
    private var isPlaying: Bool = false
    private var currentFrequency: Double = 440.0
    private var currentVelocity: Float = 0.8

    // Parameters (set from main thread, read from audio thread)
    var voiceType: VoiceType = .kick
    var filterCutoff: Float = 0.7
    var filterResonance: Float = 0.3
    var attack: Float = 0.01
    var decay: Float = 0.3
    var sustain: Float = 0.5
    var release: Float = 0.3
    var paramMod: Float = 0.0

    private enum EnvStage {
        case idle, attack, decay, sustain, release
    }

    // MARK: - Trigger

    func noteOn(frequency: Double, velocity: Float) {
        currentFrequency = frequency
        currentVelocity = velocity
        phase = 0.0
        phase2 = 0.0
        phase3 = 0.0
        envLevel = 0.0
        envStage = .attack
        envSamples = 0
        isPlaying = true
        filterBuf0 = 0.0
        filterBuf1 = 0.0
    }

    func noteOff() {
        if envStage != .idle {
            envStage = .release
            envSamples = 0
        }
    }

    // MARK: - Render

    func render(frameCount: Int, buffer: UnsafeMutablePointer<Float>) {
        for i in 0..<frameCount {
            buffer[i] = Float(nextSample())
        }
    }

    private func nextSample() -> Double {
        guard isPlaying else { return 0.0 }

        // Advance envelope
        let env = advanceEnvelope()
        if envStage == .idle {
            isPlaying = false
            return 0.0
        }

        // Generate raw oscillator based on voice type
        var sample: Double
        switch voiceType {
        case .kick:
            sample = renderKick(env: env)
        case .snare:
            sample = renderSnare(env: env)
        case .hihat:
            sample = renderHiHat(env: env)
        case .bass:
            sample = renderBass(env: env)
        case .lead:
            sample = renderLead(env: env)
        case .pad:
            sample = renderPad(env: env)
        case .perc:
            sample = renderPerc(env: env)
        case .acid:
            sample = renderAcid(env: env)
        }

        // Apply filter
        sample = applyFilter(sample)

        // Apply envelope and velocity
        sample *= env * Double(currentVelocity)

        // Soft-clip output to prevent harsh digital distortion
        sample = tanh(sample)

        return sample
    }

    // MARK: - Voice Renderers

    private func renderKick(env: Double) -> Double {
        // Pitch-dropping sine with short body
        let pitchEnv = max(0.0, 1.0 - Double(envSamples) / (sampleRate * 0.15))
        let freq = currentFrequency + pitchEnv * 200.0
        let inc = freq / sampleRate
        phase += inc
        let body = sin(phase * .pi * 2.0)

        // Sub harmonic
        phase2 += (currentFrequency * 0.5) / sampleRate
        let sub = sin(phase2 * .pi * 2.0) * 0.4

        // Transient click
        let click = pitchEnv * pitchEnv * pitchEnv * sin(phase * .pi * 8.0) * 0.5

        return tanh((body + sub + click) * 0.9)
    }

    private func renderSnare(env: Double) -> Double {
        // Tone component
        let freq = currentFrequency * 2.5
        phase += freq / sampleRate
        let tone = sin(phase * .pi * 2.0) * 0.5

        // Noise component
        noiseSampleCounter += 1
        if noiseSampleCounter >= 2 {
            noiseValue = Double.random(in: -1.0...1.0)
            noiseSampleCounter = 0
        }

        let noiseEnv = max(0.0, 1.0 - Double(envSamples) / (sampleRate * 0.12))
        let noise = noiseValue * noiseEnv

        return tanh((tone * 0.4 + noise * 0.6) * 1.2)
    }

    private func renderHiHat(env: Double) -> Double {
        // Band-passed noise with metallic partials
        noiseSampleCounter += 1
        if noiseSampleCounter >= 1 {
            noiseValue = Double.random(in: -1.0...1.0)
            noiseSampleCounter = 0
        }

        // Metallic partial
        phase += (currentFrequency * 14.0) / sampleRate
        phase2 += (currentFrequency * 17.3) / sampleRate
        let metal = (sin(phase * .pi * 2.0) + sin(phase2 * .pi * 2.0)) * 0.15

        let hatEnv = max(0.0, 1.0 - Double(envSamples) / (sampleRate * Double(0.03 + decay * 0.2)))
        return (noiseValue * 0.6 + metal) * hatEnv
    }

    private func renderBass(env: Double) -> Double {
        let freq = currentFrequency
        let inc = freq / sampleRate
        phase += inc

        // Saw + square blend
        let saw = 2.0 * (phase - floor(phase + 0.5))
        let square = phase.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1.0 : -1.0
        let mix = saw * 0.6 + square * 0.4

        // Sub oscillator
        phase2 += (freq * 0.5) / sampleRate
        let sub = sin(phase2 * .pi * 2.0) * 0.5

        return tanh((mix + sub) * 0.8)
    }

    private func renderLead(env: Double) -> Double {
        let freq = currentFrequency
        phase += freq / sampleRate

        // Detuned saw pair
        phase2 += (freq * 1.005) / sampleRate
        phase3 += (freq * 0.995) / sampleRate

        let saw1 = 2.0 * (phase.truncatingRemainder(dividingBy: 1.0)) - 1.0
        let saw2 = 2.0 * (phase2.truncatingRemainder(dividingBy: 1.0)) - 1.0
        let saw3 = 2.0 * (phase3.truncatingRemainder(dividingBy: 1.0)) - 1.0

        return (saw1 + saw2 + saw3) * 0.25
    }

    private func renderPad(env: Double) -> Double {
        let freq = currentFrequency
        // Multiple detuned sines for warm pad
        phase += freq / sampleRate
        phase2 += (freq * 1.003) / sampleRate
        phase3 += (freq * 0.997) / sampleRate

        let osc1 = sin(phase * .pi * 2.0)
        let osc2 = sin(phase2 * .pi * 2.0)
        let osc3 = sin(phase3 * .pi * 2.0)

        // Fifth harmonic for shimmer
        let shimmer = sin(phase * .pi * 2.0 * 3.0) * 0.1

        return (osc1 + osc2 + osc3) * 0.2 + shimmer
    }

    private func renderPerc(env: Double) -> Double {
        // FM percussion
        let freq = currentFrequency * 4.0
        let modRatio = 2.7 + Double(paramMod) * 2.0
        let modDepth = max(0.0, 1.0 - Double(envSamples) / (sampleRate * 0.1)) * 8.0

        phase2 += (freq * modRatio) / sampleRate
        let modulator = sin(phase2 * .pi * 2.0) * modDepth

        phase += (freq + freq * modulator) / sampleRate
        return sin(phase * .pi * 2.0) * 0.5
    }

    private func renderAcid(env: Double) -> Double {
        // Classic 303-style: saw through resonant filter with accent/slide
        let freq = currentFrequency
        phase += freq / sampleRate
        let saw = 2.0 * (phase.truncatingRemainder(dividingBy: 1.0)) - 1.0

        // Square sub
        let square = phase.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 0.5 : -0.5
        return saw * 0.5 + square * 0.2
    }

    // MARK: - Filter (2-pole low-pass)

    private func applyFilter(_ input: Double) -> Double {
        let modCutoff = Double(filterCutoff + paramMod * 0.3)
        let cutoffHz = 20.0 + pow(max(0.0, min(1.0, modCutoff)), 3.0) * 18000.0
        let resonance = Double(filterResonance)

        let c = 2.0 * sin(.pi * min(cutoffHz, sampleRate * 0.45) / sampleRate)
        let r = max(0.15, 1.0 - resonance * 0.8)

        filterBuf0 += c * (input - filterBuf0 + r * (filterBuf0 - filterBuf1))
        filterBuf1 += c * (filterBuf0 - filterBuf1)

        return filterBuf1
    }

    // MARK: - Envelope

    private func advanceEnvelope() -> Double {
        envSamples += 1

        switch envStage {
        case .idle:
            return 0.0
        case .attack:
            let attackTime = max(0.001, Double(attack) * 0.5)
            let attackSamples = attackTime * sampleRate
            envLevel = min(1.0, envLevel + 1.0 / attackSamples)
            if envLevel >= 1.0 {
                envStage = .decay
                envSamples = 0
            }
            return envLevel
        case .decay:
            let decayTime = max(0.01, Double(decay) * 1.0)
            let decaySamples = decayTime * sampleRate
            let target = Double(sustain)
            envLevel = max(target, envLevel - (1.0 - target) / decaySamples)
            if envLevel <= target + 0.001 {
                envStage = .sustain
            }
            return envLevel
        case .sustain:
            envLevel = Double(sustain)
            // For percussive sounds, auto-release
            if voiceType == .kick || voiceType == .snare || voiceType == .hihat || voiceType == .perc {
                envStage = .release
                envSamples = 0
            }
            return envLevel
        case .release:
            let releaseTime = max(0.01, Double(release) * 2.0)
            let releaseSamples = releaseTime * sampleRate
            envLevel = max(0.0, envLevel - envLevel / releaseSamples)
            if envLevel < 0.0001 {
                envLevel = 0.0
                envStage = .idle
                isPlaying = false
            }
            return envLevel
        }
    }

    // MARK: - Waveshaping

    private func tanh(_ x: Double) -> Double {
        let ex = exp(2.0 * x)
        return (ex - 1.0) / (ex + 1.0)
    }
}
