import Combine
import Foundation

/// 코드 전환 드릴을 통째로 조립한 세션. (docs/PLAN-chord-drill §4-3)
///
/// **모드 A(`ChordPracticeSession`)의 형제**다 — 왼손은 직접(넥 터치), 오른손은 자동(고른 주법).
/// 딱 하나가 다르다: 코디네이터의 **소리 게이트**를 목표 코드에 묶어, **지금 짚은 운지가 목표와
/// (관대한 기준으로) 맞을 때만** 자동 스트럼이 소리를 낸다. 틀린 모양은 긁혀도 무음이다.
///
/// ```
///   넥 ──짚기(무음)──▶ FingeringState ──┐
///                                        ▼  (soundGate: 목표와 맞나?)
///   StrumPatternPlayer ──자동 획──▶ Coordinator ──맞을 때만──▶ AudioEngine
/// ```
@MainActor
final class ChordDrillSession: ObservableObject {
    /// 넥 화면이 여기에 짚는다.
    let fingeringState: FingeringState

    /// 지금 맞혀야 할 목표 코드. 게이트가 이걸 기준으로 소리를 연다. `nil`이면 전부 통과(게이트 열림).
    var target: GuitarChord?

    /// 실제로 소리가 난 사건 — 줄 떨림·햅틱이 구독한다.
    /// 짚기는 무음(`.silent`)이므로 실질적으로 코디네이터(자동 스트럼) 스트림만 흐른다.
    var notePlayed: AnyPublisher<NotePlayedEvent, Never> {
        fingeringState.notePlayed
            .merge(with: coordinator.notePlayed)
            .eraseToAnyPublisher()
    }

    private let engine: GuitarAudioEngineProtocol?
    private let player: PickPatternPlayer
    private let coordinator: PlaySessionCoordinator

    init(engine: GuitarAudioEngineProtocol?, clock: BeatClockProtocol? = nil) {
        // 짚기는 무음 — 소리는 자동 피킹이 게이트를 통과할 때만 낸다. (모드 A와 같은 조립)
        let fingeringState = FingeringState(audioEngine: engine, soundPolicy: .silent)
        // 코드를 통째로 긁는 대신 **노래마다 정한 순서로 줄을 하나씩** 튕긴다.
        let player = PickPatternPlayer(clock: clock ?? BeatClock())
        let coordinator = PlaySessionCoordinator(audioEngine: engine)

        coordinator.setSources(
            mode: .chordPractice,
            fingering: ManualFingeringSource(state: fingeringState),
            strum: player
        )

        self.engine = engine
        self.fingeringState = fingeringState
        self.player = player
        self.coordinator = coordinator

        // ★ 목표 자리를 대부분 완성하면 소리 — 틀린 프렛이 없는 초보자 보조 기준으로 게이트를 연다.
        coordinator.soundGate = { [weak self] fingering in
            guard let self, let target = self.target else { return true }
            return ChordJudge.matchesForAssistedPlayback(
                played: fingering.frets,
                target: target.fingering.frets
            )
        }

        // 실제로 울릴 줄은 **목표 코드의 보이싱**으로 정한다 — 안 치는 줄(뮤트 X)은 소리도
        // 줄 떨림도 나지 않는다. 짚기 자체가 무음이라 자유 개방현이 섞일 일도 없다.
        coordinator.voicingOverride = { [weak self] in self?.target?.fingering }
    }

    // MARK: - 수명주기

    func startEngine() { engine?.start() }

    /// 자동 피킹을 시작한다. 코드 드릴에서는 정답 마디마다 한 번씩 재생해 악보 칸과 리듬 시작점을 맞춘다.
    func play(pick: PickPattern, bpm: Double? = nil, looping: Bool = true) {
        player.bpmOverride = bpm
        player.play(pick, looping: looping)
    }

    func stopPlaying() { player.stop() }

    func end() {
        player.stop()
        coordinator.stop()
        fingeringState.releaseAll()
        engine?.stop()
    }
}
