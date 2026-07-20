#if canImport(AudioKit)
import AudioKit
import AudioToolbox
import AVFoundation
import Foundation

/// AudioKit(`AudioEngine` + `AppleSampler`) 기반의 기타 오디오 엔진.
///
/// 파일 전체를 `#if canImport(AudioKit)`로 감싸, AudioKit 패키지가 없는 환경에서도
/// 프로젝트가 정상적으로 컴파일되도록 한다.
@MainActor
final class AudioKitAudioEngine: GuitarAudioEngineBase, GuitarAudioEngineProtocol {
    private let engine = AudioEngine()
    private let samplers = (0..<GuitarFingering.stringCount).map { _ in AppleSampler() }
    private lazy var mixer = Mixer(samplers.map { $0 as Node })

    override init() {
        super.init()
        setupEngine()
    }

    override func setupEngine() {
        guard !isSetUp else { return }
        configureAudioSession()

        engine.output = mixer

        loadSoundFont()
        isSetUp = true
    }

    override func performStart() {
        do {
            try engine.start()
        } catch {
            logAudioError("Failed to start guitar audio engine: \(error.localizedDescription)")
        }
    }

    override func performStop() {
        engine.stop()
    }

    override func playNote(stringIndex: Int, note: Int, velocity: UInt8) {
        samplers[stringIndex].play(
            noteNumber: MIDINoteNumber(note),
            velocity: MIDIVelocity(velocity),
            channel: 0
        )
    }

    override func stopNote(stringIndex: Int, note: Int) {
        samplers[stringIndex].stop(noteNumber: MIDINoteNumber(note), channel: 0)
    }

    // MARK: - Setup helpers

    private func loadSoundFont() {
        guard let soundFontURL = Bundle.main.url(forResource: "AcousticGuitar", withExtension: "sf2") else {
            logAudioError("AcousticGuitar.sf2 was not found in the app bundle.")
            return
        }

        for sampler in samplers {
            do {
                try sampler.samplerUnit.loadSoundBankInstrument(
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

    private func configureSamplerExpression(_ sampler: AppleSampler) {
        sampler.samplerUnit.sendController(
            releaseTimeControl,
            withValue: releaseTimeValue,
            onChannel: 0
        )
    }
}
#endif
