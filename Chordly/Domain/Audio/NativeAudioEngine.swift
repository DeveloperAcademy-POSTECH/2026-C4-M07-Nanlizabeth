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

    /// 샘플러 6개가 전부 사운드폰트를 물고 있는가.
    ///
    /// 이 값이 `false`인 채로 소리를 내면 **음정만 맞는 사인파**가 난다. 그래서 켤 때마다 확인한다.
    private var isSoundFontLoaded = false

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
        // 그래프가 새로 만들어졌으면 음색부터 다시 읽는다. (아래 `isSoundFontLoaded` 설명 참고)
        if !isSoundFontLoaded {
            loadSoundFont()
        }

        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            logAudioError("Failed to start guitar audio engine: \(error.localizedDescription)")
        }
    }

    /// 화면을 벗어나거나 중단이 걸렸을 때 렌더링을 멈춘다.
    ///
    /// ⚠️ **`stop()`이 아니라 `pause()`인 이유가 중요하다.**
    /// `stop()`은 샘플러를 초기화 해제해 **로드해둔 사운드폰트를 날린다.** 그 상태로 다시 켜면
    /// 음정은 맞는데 음색만 기본음으로 떨어져 **기타가 사인파(신디사이저)처럼 들린다.**
    /// `pause()`는 렌더링만 멈추고 음색은 그대로 둔다.
    override func performStop() {
        engine.pause()
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

        // 샘플러가 새것이라 음색은 아직 안 들어 있다.
        isSoundFontLoaded = false
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

        var loadedCount = 0

        for sampler in samplers {
            do {
                try sampler.loadSoundBankInstrument(
                    at: soundFontURL,
                    program: 0,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: 0
                )
                configureSamplerExpression(sampler)
                loadedCount += 1
            } catch {
                logAudioError("Failed to load AcousticGuitar.sf2: \(error.localizedDescription)")
            }
        }

        // 한 줄이라도 실패했으면 다음에 켤 때 다시 시도한다 — 일부만 사인파로 나는 게 제일 헷갈린다.
        isSoundFontLoaded = loadedCount == samplers.count
    }

    private func configureSamplerExpression(_ sampler: AVAudioUnitSampler) {
        sampler.sendController(
            releaseTimeControl,
            withValue: releaseTimeValue,
            onChannel: 0
        )
    }
}
