import Combine
import Foundation

/// 모드 A(코드 연습)를 **화면에 묶는** 컨트롤러. (ROADMAP 태스크 I1 화면 연결)
///
/// `ChordPracticeSession`(엔진·운지·자동 스트럼 조립)과 넥 화면(`NeckViewModel`)을 하나로 잇는다.
/// **핵심은 넥과 자동 스트럼이 같은 운지상태·같은 엔진을 공유**한다는 것이다:
///
/// - 넥을 짚으면 → 세션의 `FingeringState`가 개별 발음 (SPEC §4)
/// - 재생을 켜면 → 자동 스트럼이 **그 순간 짚은 운지**로 리듬을 긁는다 (SPEC 모드 A)
/// - 줄 떨림·햅틱은 둘을 **합친 스트림**을 먹으므로, 손으로 짚든 자동으로 긁히든 다 반응한다
///
/// 프로토타입 셸이 넥·스트럼 뷰모델마다 엔진을 따로 만들던 문제(ARCHITECTURE §1)를, 이 컨트롤러는
/// 엔진 하나만 만들어 해소한다.
@MainActor
final class ChordModeController: ObservableObject {
    /// 넥 화면이 그대로 쓰는 뷰모델. 세션의 운지상태에 묶여 있다.
    let neck: NeckViewModel

    @Published private(set) var isPlaying = false

    private let session: ChordPracticeSession

    /// 판정 햅틱 (H3). **기본은 꺼짐(target=nil)** — 모드 A엔 정답이 없기 때문 (SPEC §8).
    /// "이 코드를 짚어보세요" 식의 목표가 정해지면 `setTargetChord(_:)`로 켠다.
    private let judgment = ChordJudgmentController()

    init(engine: GuitarAudioEngineProtocol? = nil, clock: BeatClockProtocol? = nil) {
        let engine = engine ?? GuitarAudioEngineFactory.makeDefault()
        let session = ChordPracticeSession(engine: engine, clock: clock)

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
    }

    // MARK: - 화면 수명주기

    func start() {
        session.startEngine()
    }

    func end() {
        session.end()
        isPlaying = false
    }

    // MARK: - 재생

    /// 재생 버튼. 고른 주법으로 자동 스트럼을 켠다. 짚기는 재생과 무관하게 항상 소리 난다.
    ///
    /// - Parameters:
    ///   - pattern: 스트로크 선택(U4)에서 고른 주법. 없으면 호출부가 기본값을 준다.
    ///   - bpm: 유저가 정한 BPM. `nil`이면 주법 권장값.
    func play(pattern: StrumPattern, bpm: Double? = nil) {
        session.play(pattern: pattern, bpm: bpm)
        isPlaying = true
    }

    func stop() {
        session.stopPlaying()
        isPlaying = false
    }

    /// "이 코드를 짚어보세요" 목표를 정한다. 정하면 다른 코드를 짚을 때 진동으로 알려준다 (H3).
    /// `nil`이면 판정을 끈다. (연습 화면이 도입되면 여기에 목표를 넣는다 — SPEC §8 결정 후.)
    func setTargetChord(_ chord: GuitarChord?) {
        judgment.target = chord
    }

    /// 상대 기기와 **연결되면** 이 iPhone은 소리를 끄고 **진동만** 준다 (모드 C) — 소리는 iPad에서 난다.
    /// 자동 스트럼도 멈춘다. 연결이 끊기면 다시 소리가 난다(모드 A).
    func setConnected(_ connected: Bool) {
        session.fingeringState.isMuted = connected
        // 연결되면 짚을 때 진동 안 함 — 손맛은 iPad가 튕길 때 신호로 온다.
        neck.setHapticsEnabled(!connected)
        if connected {
            stop()
        }
    }
}
