import Combine
import Foundation

/// 모드 A(코드 연습)를 **화면에 묶는** 컨트롤러. (ROADMAP 태스크 I1 화면 연결)
///
/// `ChordPracticeSession`(엔진·운지·자동 스트럼 조립)과 넥 화면(`NeckViewModel`)을 하나로 잇는다.
/// **핵심은 넥과 자동 스트럼이 같은 운지상태·같은 엔진을 공유**한다는 것이다:
///
/// - **단독 + 자동재생 전**엔 → 짚은 줄이 **바로 소리 난다**(개별 발음). 재생하기 전에도 짚어보며
///   소리를 들을 수 있게 한 것 (2026-07-23 개선). 재생을 켜면 짚기는 조용해지고 자동 주법이 낸다.
/// - **자동 스트럼이 BPM대로 계속 긁으며** 그 순간 짚은 운지로 소리 낸다 (스트로크 모드가
///   진행을 자동으로 돌리는 것과 대칭). 재생 버튼으로 켠다.
/// - **연결되면(모드 C)** 짚기는 무음 — 소리는 iPad에서 난다.
///
/// 프로토타입 셸이 넥·스트럼 뷰모델마다 엔진을 따로 만들던 문제(ARCHITECTURE §1)를, 이 컨트롤러는
/// 엔진 하나만 만들어 해소한다.
@MainActor
final class ChordModeController: ObservableObject {
    /// 넥이 짚을 수 있는 최고 프렛 — 넥이 몸통(사운드홀)과 만나는 12프렛까지. 실제 기타의
    /// 연주 영역(약 한 옥타브)과 맞춘 값. (docs/PLAN-neck-position)
    static let maxFret = 12

    /// 넥 화면이 그대로 쓰는 뷰모델. 세션의 운지상태에 묶여 있다.
    let neck: NeckViewModel

    @Published private(set) var isPlaying = false

    /// 상대 기기와 연결됐는가 (모드 C). 연결되면 iPhone 짚기는 무음.
    private var connected = false

    /// 지금 쓰는 넥 입력 방식 (A/B). 기본은 슬라이더.
    @Published private(set) var neckPositionMode: NeckPositionMode = .slider

    /// 🎚️ 슬라이더 버전 — 화면 슬라이드바가 바인딩한다.
    let sliderPosition: SliderNeckPositionProvider
    /// 📱 코어모션 버전.
    let motionPosition: MotionNeckPositionProvider

    private let session: ChordPracticeSession
    private var positionCancellable: AnyCancellable?

    /// 판정 햅틱 (H3). **기본은 꺼짐(target=nil)** — 모드 A엔 정답이 없기 때문 (SPEC §8).
    /// "이 코드를 짚어보세요" 식의 목표가 정해지면 `setTargetChord(_:)`로 켠다.
    private let judgment = ChordJudgmentController()

    init(engine: GuitarAudioEngineProtocol? = nil, clock: BeatClockProtocol? = nil) {
        let engine = engine ?? GuitarAudioEngineFactory.makeDefault()
        let session = ChordPracticeSession(engine: engine, clock: clock)

        // 화면엔 프렛 칸이 `fretCount`개 보이므로, 오프셋은 (최고 프렛 - 보이는 칸)까지 갈 수 있다.
        let maxPosition = max(Self.maxFret - NeckGeometry.fretCount, 0)
        self.sliderPosition = SliderNeckPositionProvider(maxPosition: maxPosition)
        self.motionPosition = MotionNeckPositionProvider(maxPosition: maxPosition)

        self.session = session
        // 판정기를 넥의 운지 변화에 물려둔다. target이 없으면 아무 일도 안 한다.
        judgment.connect(to: session.fingeringState.fingeringChanged)
        // 넥은 세션의 운지상태를 공유하고, 엔진 수명은 세션이 관리하므로 넥엔 넘기지 않는다(nil).
        // 피드백은 세션의 합친 스트림 — 자동으로 긁힌 줄도 떨리고 진동한다.
        self.neck = NeckViewModel(
            fingeringState: session.fingeringState,
            audioEngine: nil,
            feedbackPublisher: session.notePlayed
        )

        bindActiveProvider()
    }

    /// 지금 켜진 입력 방식.
    private var activeProvider: NeckPositionProviding {
        neckPositionMode == .slider ? sliderPosition : motionPosition
    }

    /// 켜진 공급자의 포지션 변화를 넥 오프셋에 물린다.
    private func bindActiveProvider() {
        let provider = activeProvider
        positionCancellable = provider.positionChanged
            .sink { [weak self] offset in self?.neck.setFretOffset(offset) }
        neck.setFretOffset(provider.position)
    }

    /// 입력 방식을 바꾼다 (A/B 전환). 이전 방식은 멈추고 포지션은 처음(1프렛)으로 되돌린다.
    func setNeckPositionMode(_ mode: NeckPositionMode) {
        guard mode != neckPositionMode else { return }
        activeProvider.stop()
        neckPositionMode = mode
        sliderPosition.position = 0
        // 새 입력을 먼저 켜서(모션은 여기서 포지션·중립을 처음으로 리셋) 초기값을 확정한 뒤 배선한다.
        activeProvider.start()
        bindActiveProvider()
    }

    // MARK: - 화면 수명주기

    func start() {
        session.startEngine()
        activeProvider.start()
        updateFrettingSounds()
    }

    func end() {
        activeProvider.stop()
        session.end()
        isPlaying = false
    }

    // MARK: - 재생

    /// 자동 스트럼을 켠다. **재생 버튼이 아니라 화면 진입 시** 호출된다 — 스트로크 모드가
    /// 진행을 자동으로 돌리듯, 코드 모드는 주법을 자동으로 돌린다.
    ///
    /// - Parameters:
    ///   - pattern: 스트로크 선택(U4)에서 고른 주법. 없으면 호출부가 기본값을 준다.
    ///   - bpm: 유저가 정한 BPM. `nil`이면 주법 권장값.
    func play(pattern: StrumPattern, bpm: Double? = nil) {
        session.play(pattern: pattern, bpm: bpm)
        isPlaying = true
        updateFrettingSounds()   // 재생 중엔 짚기 무음 — 자동 주법이 소리 낸다
    }

    func stop() {
        session.stopPlaying()
        isPlaying = false
        updateFrettingSounds()   // 재생 멈추면 다시 짚는 소리가 나게
    }

    /// **단독 + 자동재생 꺼짐**일 때만 짚은 줄이 바로 소리 나게 한다.
    /// 재생 중(자동 주법이 소리)이거나 연결됨(iPad가 소리)이면 짚기는 무음.
    private func updateFrettingSounds() {
        session.setFrettingSounds(!isPlaying && !connected)
    }

    /// "이 코드를 짚어보세요" 목표를 정한다. 정하면 다른 코드를 짚을 때 진동으로 알려준다 (H3).
    /// `nil`이면 판정을 끈다. (연습 화면이 도입되면 여기에 목표를 넣는다 — SPEC §8 결정 후.)
    func setTargetChord(_ chord: GuitarChord?) {
        judgment.target = chord
    }

    /// 상대 기기와 **연결되면**(모드 C) 이 iPhone에선 자동 스트럼을 멈춘다 — 소리는 iPad에서 난다.
    /// 짚기는 어차피 무음(`.silent`)이므로 그대로 두고, 손맛(햅틱)만 끈다(iPad 튕김 신호로 대체).
    /// 연결이 끊기면 화면이 자동 스트럼을 다시 켠다.
    func setConnected(_ connected: Bool) {
        self.connected = connected
        // 연결되면 짚을 때 진동 안 함 — 손맛은 iPad가 튕길 때 신호로 온다.
        neck.setHapticsEnabled(!connected)
        if connected {
            stop()   // 자동 주법 정지. stop()이 짚기 소리도 무음으로 갱신한다.
        } else {
            updateFrettingSounds()   // 연결 해제 → 단독이면 짚는 소리 복귀
        }
    }
}
