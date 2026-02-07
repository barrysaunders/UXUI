import AVFoundation
import Combine

/// Core audio engine managing AVAudioEngine, mixer, effects, and per-track source nodes.
final class AudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let mainMixer = AVAudioMixerNode()
    private let reverbNode = AVAudioUnitReverb()
    private let delayNode = AVAudioUnitDelay()

    private var trackNodes: [UUID: TrackAudioNode] = [:]

    private let format: AVAudioFormat

    @Published var isRunning = false
    @Published var masterVolume: Float = 0.8 {
        didSet { mainMixer.outputVolume = masterVolume }
    }
    @Published var reverbMix: Float = 0.3 {
        didSet { reverbNode.wetDryMix = reverbMix * 100 }
    }
    @Published var delayMix: Float = 0.2 {
        didSet { delayNode.wetDryMix = delayMix * 100 }
    }

    struct TrackAudioNode {
        let sourceNode: AVAudioSourceNode
        let synth: Synthesizer
        let mixerNode: AVAudioMixerNode
    }

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        setupAudioSession()
        setupGraph()
    }

    // MARK: - Setup

    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("Audio session setup error: \(error)")
        }
        #endif
    }

    private func setupGraph() {
        engine.attach(mainMixer)
        engine.attach(reverbNode)
        engine.attach(delayNode)

        reverbNode.loadFactoryPreset(.mediumHall)
        reverbNode.wetDryMix = reverbMix * 100

        delayNode.delayTime = 0.375
        delayNode.feedback = 40
        delayNode.wetDryMix = delayMix * 100

        let outputFormat = engine.outputNode.inputFormat(forBus: 0)

        engine.connect(mainMixer, to: reverbNode, format: outputFormat)
        engine.connect(reverbNode, to: delayNode, format: outputFormat)
        engine.connect(delayNode, to: engine.mainMixerNode, format: outputFormat)

        mainMixer.outputVolume = masterVolume
    }

    // MARK: - Track Management

    func addTrack(for track: Track) -> Synthesizer {
        if let existing = trackNodes[track.id] {
            return existing.synth
        }

        let synth = Synthesizer()
        synth.voiceType = track.voiceType
        synth.filterCutoff = track.filterCutoff
        synth.filterResonance = track.filterResonance
        synth.attack = track.attack
        synth.decay = track.decay
        synth.sustain = track.sustain
        synth.release = track.release

        let mixerNode = AVAudioMixerNode()
        engine.attach(mixerNode)

        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        let sourceNode = AVAudioSourceNode(format: monoFormat) { [weak synth] _, _, frameCount, audioBufferList -> OSStatus in
            guard let synth = synth else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            let frames = Int(frameCount)
            if let data = buffer.mData?.assumingMemoryBound(to: Float.self) {
                synth.render(frameCount: frames, buffer: data)
            }
            return noErr
        }

        engine.attach(sourceNode)

        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        engine.connect(sourceNode, to: mixerNode, format: monoFormat)
        engine.connect(mixerNode, to: mainMixer, format: outputFormat)

        mixerNode.outputVolume = track.volume
        mixerNode.pan = track.pan

        let trackNode = TrackAudioNode(sourceNode: sourceNode, synth: synth, mixerNode: mixerNode)
        trackNodes[track.id] = trackNode

        return synth
    }

    func removeTrack(id: UUID) {
        guard let node = trackNodes.removeValue(forKey: id) else { return }
        engine.disconnectNodeOutput(node.sourceNode)
        engine.disconnectNodeOutput(node.mixerNode)
        engine.detach(node.sourceNode)
        engine.detach(node.mixerNode)
    }

    func synthForTrack(id: UUID) -> Synthesizer? {
        return trackNodes[id]?.synth
    }

    func updateTrackVolume(id: UUID, volume: Float) {
        trackNodes[id]?.mixerNode.outputVolume = volume
    }

    func updateTrackPan(id: UUID, pan: Float) {
        trackNodes[id]?.mixerNode.pan = pan
    }

    func updateTrackMute(id: UUID, isMuted: Bool) {
        trackNodes[id]?.mixerNode.outputVolume = isMuted ? 0.0 : 1.0
    }

    func updateDelayTime(bpm: Double) {
        // Sync delay to tempo (dotted eighth)
        let beatDuration = 60.0 / bpm
        delayNode.delayTime = beatDuration * 0.75
    }

    // MARK: - Engine Control

    func start() {
        guard !isRunning else { return }
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("Engine start error: \(error)")
        }
    }

    func stop() {
        engine.stop()
        isRunning = false
    }
}
