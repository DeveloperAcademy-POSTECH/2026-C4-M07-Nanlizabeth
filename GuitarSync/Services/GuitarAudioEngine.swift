import AVFoundation
import AudioToolbox
import Foundation

#if USE_AUDIOKIT && canImport(AudioKit)
import AudioKit
#endif

@MainActor
final class GuitarAudioEngine {
    private let openStringMIDINotes = [40, 45, 50, 55, 59, 64]
    private let noteDuration: TimeInterval = 3.6
    private let releaseTimeControl: UInt8 = 72
    private let releaseTimeValue: UInt8 = 78
    private var lastPlayedNotes = Array<Int?>(repeating: nil, count: GuitarFingering.stringCount)
    private var scheduledStopWorkItems = Array<DispatchWorkItem?>(repeating: nil, count: GuitarFingering.stringCount)
    private var isSetUp = false

    #if USE_AUDIOKIT && canImport(AudioKit)
    private let engine = AudioEngine()
    private let samplers = (0..<GuitarFingering.stringCount).map { _ in AppleSampler() }
    private lazy var mixer = Mixer(samplers.map { $0 as Node })
    #else
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()
    private let samplers = (0..<GuitarFingering.stringCount).map { _ in AVAudioUnitSampler() }
    #endif

    init() {
        setupEngine()
    }

    func setupEngine() {
        guard !isSetUp else { return }
        configureAudioSession()

        #if USE_AUDIOKIT && canImport(AudioKit)
        engine.output = mixer
        #else
        engine.attach(mixer)
        engine.attach(reverb)
        configureReverb()

        for sampler in samplers {
            engine.attach(sampler)
            engine.connect(sampler, to: mixer, format: nil)
        }
        engine.connect(mixer, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)
        #endif

        loadSoundFont()
        isSetUp = true
    }

    func start() {
        setupEngine()

        do {
            #if USE_AUDIOKIT && canImport(AudioKit)
            try engine.start()
            #else
            if !engine.isRunning {
                try engine.start()
            }
            #endif
        } catch {
            logAudioError("Failed to start guitar audio engine: \(error.localizedDescription)")
        }
    }

    func stop() {
        stopAllStrings()

        #if USE_AUDIOKIT && canImport(AudioKit)
        engine.stop()
        #else
        engine.stop()
        #endif
    }

    func noteNumber(stringIndex: Int, fret: Int) -> Int? {
        guard openStringMIDINotes.indices.contains(stringIndex), (0...24).contains(fret) else {
            return nil
        }

        return openStringMIDINotes[stringIndex] + fret
    }

    func pluckString(stringIndex: Int, fretNumber: Int, velocity: UInt8 = 96) {
        guard samplers.indices.contains(stringIndex), fretNumber >= 0 else { return }
        guard let note = noteNumber(stringIndex: stringIndex, fret: fretNumber) else { return }

        stopString(stringIndex: stringIndex, cancelScheduledStop: true)

        #if USE_AUDIOKIT && canImport(AudioKit)
        samplers[stringIndex].play(
            noteNumber: MIDINoteNumber(note),
            velocity: MIDIVelocity(velocity),
            channel: 0
        )
        #else
        samplers[stringIndex].startNote(
            UInt8(note),
            withVelocity: velocity,
            onChannel: 0
        )
        #endif

        lastPlayedNotes[stringIndex] = note
        scheduleStop(stringIndex: stringIndex, after: noteDuration)
    }

    func pluckStringSequence(
        _ stringIndices: [Int],
        frets: [Int],
        baseVelocity: UInt8 = 96,
        interval: TimeInterval = 0.018
    ) {
        for (offset, stringIndex) in stringIndices.enumerated() {
            let delay = interval * TimeInterval(offset)
            let velocity = sequenceVelocity(
                baseVelocity: baseVelocity,
                stringIndex: stringIndex,
                offset: offset
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                Task { @MainActor in
                    guard let self, frets.indices.contains(stringIndex) else { return }
                    self.pluckString(
                        stringIndex: stringIndex,
                        fretNumber: frets[stringIndex],
                        velocity: velocity
                    )
                }
            }
        }
    }

    func strum(
        frets: [Int],
        direction: StrumDirection,
        velocity: UInt8 = 96,
        interval: TimeInterval = 0.035
    ) {
        let indices: [Int]
        switch direction {
        case .down:
            indices = Array(0..<GuitarFingering.stringCount)
        case .up:
            indices = Array((0..<GuitarFingering.stringCount).reversed())
        }

        pluckStringSequence(
            indices,
            frets: frets,
            baseVelocity: velocity,
            interval: interval
        )
    }

    func stopString(stringIndex: Int) {
        stopString(stringIndex: stringIndex, cancelScheduledStop: true)
    }

    private func stopString(stringIndex: Int, cancelScheduledStop: Bool) {
        guard samplers.indices.contains(stringIndex),
              lastPlayedNotes.indices.contains(stringIndex)
        else {
            return
        }

        if cancelScheduledStop {
            scheduledStopWorkItems[stringIndex]?.cancel()
            scheduledStopWorkItems[stringIndex] = nil
        }

        guard let note = lastPlayedNotes[stringIndex] else { return }

        #if USE_AUDIOKIT && canImport(AudioKit)
        samplers[stringIndex].stop(noteNumber: MIDINoteNumber(note), channel: 0)
        #else
        samplers[stringIndex].stopNote(UInt8(note), onChannel: 0)
        #endif

        lastPlayedNotes[stringIndex] = nil
    }

    func stopAllStrings() {
        for stringIndex in 0..<GuitarFingering.stringCount {
            stopString(stringIndex: stringIndex)
        }
    }

    private func scheduleStop(stringIndex: Int, after delay: TimeInterval) {
        guard scheduledStopWorkItems.indices.contains(stringIndex) else { return }

        scheduledStopWorkItems[stringIndex]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.stopString(stringIndex: stringIndex, cancelScheduledStop: false)
                self.scheduledStopWorkItems[stringIndex] = nil
            }
        }

        scheduledStopWorkItems[stringIndex] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            logAudioError("Failed to configure audio session: \(error.localizedDescription)")
        }
        #endif
    }

    #if USE_AUDIOKIT && canImport(AudioKit)
    #else
    private func configureReverb() {
        reverb.loadFactoryPreset(.mediumRoom)
        reverb.wetDryMix = 14
    }
    #endif

    private func loadSoundFont() {
        guard let soundFontURL = Bundle.main.url(forResource: "AcousticGuitar", withExtension: "sf2") else {
            logAudioError("AcousticGuitar.sf2 was not found in the app bundle.")
            return
        }

        for sampler in samplers {
            do {
                #if USE_AUDIOKIT && canImport(AudioKit)
                try sampler.samplerUnit.loadSoundBankInstrument(
                    at: soundFontURL,
                    program: 0,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: 0
                )
                #else
                try sampler.loadSoundBankInstrument(
                    at: soundFontURL,
                    program: 0,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: 0
                )
                #endif
                configureSamplerExpression(sampler)
            } catch {
                logAudioError("Failed to load AcousticGuitar.sf2: \(error.localizedDescription)")
            }
        }
    }

    #if USE_AUDIOKIT && canImport(AudioKit)
    private func configureSamplerExpression(_ sampler: AppleSampler) {
        sampler.samplerUnit.sendController(
            releaseTimeControl,
            withValue: releaseTimeValue,
            onChannel: 0
        )
    }
    #else
    private func configureSamplerExpression(_ sampler: AVAudioUnitSampler) {
        sampler.sendController(
            releaseTimeControl,
            withValue: releaseTimeValue,
            onChannel: 0
        )
    }
    #endif

    private func sequenceVelocity(baseVelocity: UInt8, stringIndex: Int, offset: Int) -> UInt8 {
        let textureByString = [3, 1, 2, -1, 0, -2]
        let texture = textureByString.indices.contains(stringIndex) ? textureByString[stringIndex] : 0
        let firstContactAccent = offset == 0 ? 5 : 0
        let rollOff = min(offset * 2, 8)
        return clampedVelocity(Int(baseVelocity) + firstContactAccent + texture - rollOff)
    }

    private func clampedVelocity(_ value: Int) -> UInt8 {
        UInt8(min(max(value, 42), 124))
    }

    private func logAudioError(_ message: String) {
        #if DEBUG
        print("[GuitarAudioEngine] \(message)")
        #endif
    }
}
