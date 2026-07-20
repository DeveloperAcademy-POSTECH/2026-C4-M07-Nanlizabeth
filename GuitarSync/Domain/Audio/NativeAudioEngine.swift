import AVFoundation
import AudioToolbox
import Foundation

/// AVAudioEngine + AVAudioUnitSampler 기반의 네이티브 기타 오디오 엔진.
@MainActor
final class NativeAudioEngine: GuitarAudioEngineBase, GuitarAudioEngineProtocol {
    // 미디어 서비스가 리셋되면 아래 객체들은 전부 무효가 되어 **새로 만드는 것 말고는 방법이 없다.**
    // `let`이 아닌 이유가 그것이다. (ROADMAP 태스크 A4 · `rebuildEngine()`)
    private var engine = AVAudioEngine()
    private var mixer = AVAudioMixerNode()
    private var reverb = AVAudioUnitReverb()
    private var samplers = (0..<GuitarFingering.stringCount).map { _ in AVAudioUnitSampler() }

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

    override var isEngineRunning: Bool { engine.isRunning }

    /// 엔진·노드를 전부 버리고 새로 만든다. (ROADMAP 태스크 A4)
    ///
    /// 미디어 서비스가 리셋되면 기존 `AVAudioEngine`과 붙어 있던 노드는 살릴 수 없다.
    /// 재연결만으로는 안 되고 **객체부터 새로 만들어야** 한다.
    override func rebuildEngine() {
        engine.stop()

        engine = AVAudioEngine()
        mixer = AVAudioMixerNode()
        reverb = AVAudioUnitReverb()
        samplers = (0..<GuitarFingering.stringCount).map { _ in AVAudioUnitSampler() }

        isSetUp = false
        setupEngine()
        performStart()
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
