import Combine
import Foundation

/// 모드 A(코드 연습)를 통째로 조립한 세션. (ROADMAP 태스크 I1 · SPEC §2 모드 A)
///
/// **왼손은 직접(넥 터치), 오른손은 자동(고른 주법).** 이 객체 하나가 그 조합을 완성한다.
///
/// ```
///   넥 화면 ──짚기──▶ FingeringState ──(그 순간 운지)──┐
///                                                        ▼
///   StrumPatternPlayer ──자동 획──▶ AutoStrumSource ──▶ Coordinator ──▶ AudioEngine
/// ```
///
/// ## 엔진은 하나만 쓴다
///
/// `FingeringState`(짚는 순간 발음, SPEC §4)와 코디네이터(자동 스트럼)가 **같은 엔진 하나**를
/// 나눠 쓴다. 프로토타입 셸이 넥·스트럼 뷰모델마다 엔진을 따로 만들어 메모리를 두 배 쓰던 문제
/// (ARCHITECTURE §1 경고)를, 이 조립 객체는 애초에 안 만든다.
///
/// ## 소리가 두 겹으로 난다 — 의도된 것
///
/// 모드 A에서 프렛을 누르면 **그 자리에서 즉시** 소리가 나고(개별 발음), 그 위에 자동 주법이
/// 리듬으로 겹쳐 긁는다. 둘 다 SPEC이 요구하는 동작이다 (SPEC §2 모드 A + §4 개별 발음).
@MainActor
final class ChordPracticeSession: ObservableObject {
    /// 넥 화면이 여기에 짚는다. `pressesChanged(_:)`로 운지를 넣으면 된다.
    let fingeringState: FingeringState

    @Published private(set) var isPlaying = false
    @Published private(set) var currentPattern: StrumPattern?

    /// 실제로 소리가 난 사건 — 줄 애니메이션(U3)·햅틱(H1)이 구독한다.
    /// 개별 발음과 자동 스트럼을 **한 스트림으로 합쳐** 내보낸다.
    var notePlayed: AnyPublisher<NotePlayedEvent, Never> {
        fingeringState.notePlayed
            .merge(with: coordinator.notePlayed)
            .eraseToAnyPublisher()
    }

    private let engine: GuitarAudioEngineProtocol?
    private let player: StrumPatternPlayer
    private let coordinator: PlaySessionCoordinator

    /// - Parameters:
    ///   - engine: 소리를 내는 엔진. 프리뷰·테스트에서 `nil`이면 조용히 조립만 된다.
    ///   - clock: 박자 심장. 테스트는 `MockBeatClock`을 넣는다.
    init(engine: GuitarAudioEngineProtocol?, clock: BeatClockProtocol? = nil) {
        let fingeringState = FingeringState(audioEngine: engine, soundPolicy: .pluckOnPress)
        let player = StrumPatternPlayer(clock: clock ?? BeatClock())
        let coordinator = PlaySessionCoordinator(audioEngine: engine)

        // 왼손 = 넥의 운지 상태, 오른손 = 자동 주법 플레이어.
        coordinator.setSources(
            mode: .chordPractice,
            fingering: ManualFingeringSource(state: fingeringState),
            strum: AutoStrumSource(player: player)
        )

        self.engine = engine
        self.fingeringState = fingeringState
        self.player = player
        self.coordinator = coordinator
    }

    /// 엔진을 켠다. 넥 화면 진입 시 부른다.
    func startEngine() {
        engine?.start()
    }

    /// 자동 주법을 시작한다. 재생(▶) 버튼이 부른다.
    ///
    /// - Parameter bpm: 유저가 정한 BPM. `nil`이면 주법의 권장 BPM.
    func play(pattern: StrumPattern, bpm: Double? = nil) {
        player.bpmOverride = bpm
        currentPattern = pattern
        player.play(pattern: pattern, looping: true)
        isPlaying = true
    }

    /// 자동 주법만 멈춘다. 왼손 짚기는 계속 소리 난다.
    func stopPlaying() {
        player.stop()
        isPlaying = false
    }

    /// 세션을 끝낸다. 넥 화면 이탈 시 부른다.
    func end() {
        player.stop()
        coordinator.stop()
        fingeringState.releaseAll()
        isPlaying = false
        engine?.stop()
    }
}
