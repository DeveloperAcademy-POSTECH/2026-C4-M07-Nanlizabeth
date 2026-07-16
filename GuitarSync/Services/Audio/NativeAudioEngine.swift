import AVFoundation
import AudioToolbox
import Foundation

/// AVAudioEngine + AVAudioUnitSampler 기반의 네이티브 기타 오디오 엔진.
@MainActor
final class NativeAudioEngine: GuitarAudioEngineBase, GuitarAudioEngineProtocol {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()
    private let samplers = (0..<GuitarFingering.stringCount).map { _ in AVAudioUnitSampler() }

    override init() {
        super.init()
        setupEngine()
    }

    override func setupEngine() {
        guard !isSetUp else { return }
        configureAudioSession()

        engine.attach(mixer)
        engine.attach(reverb)
        configureReverb()

        for sampler in samplers {
            engine.attach(sampler)
            engine.connect(sampler, to: mixer, format: nil)
        }
        engine.connect(mixer, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)

        loadSoundFont()
        isSetUp = true
    }

    override func performStart() {
        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            logAudioError("Failed to start guitar audio engine: \(error.localizedDescription)")
        }
    }

    override func performStop() {
        engine.stop()
    }

    override func playNote(stringIndex: Int, note: Int, velocity: UInt8) {
        samplers[stringIndex].startNote(
            UInt8(note),
            withVelocity: velocity,
            onChannel: 0
        )
    }

    override func stopNote(stringIndex: Int, note: Int) {
        samplers[stringIndex].stopNote(UInt8(note), onChannel: 0)
    }

    // MARK: - Setup helpers

    private func configureReverb() {
        reverb.loadFactoryPreset(.mediumRoom)
        reverb.wetDryMix = 14
    }

    private func loadSoundFont() {
        guard let soundFontURL = Bundle.main.url(forResource: "AcousticGuitar", withExtension: "sf2") else {
            logAudioError("AcousticGuitar.sf2 was not found in the app bundle.")
            return
        }

        for sampler in samplers {
            do {
                try sampler.loadSoundBankInstrument(
                    at: soundFontURL,
                    program: 0,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: 0
                )
                configureSamplerExpression(sampler)
            } catch {
                logAudioError("Failed to load AcousticGuitar.sf2: \(error.localizedDescription)")
            }
        }
    }

    private func configureSamplerExpression(_ sampler: AVAudioUnitSampler) {
        sampler.sendController(
            releaseTimeControl,
            withValue: releaseTimeValue,
            onChannel: 0
        )
    }
}
