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
    private let player: StrumPatternPlayer
    private let coordinator: PlaySessionCoordinator

    init(engine: GuitarAudioEngineProtocol?, clock: BeatClockProtocol? = nil) {
        // 짚기는 무음 — 소리는 자동 주법이 게이트를 통과할 때만 낸다. (모드 A와 동일한 조립)
        let fingeringState = FingeringState(audioEngine: engine, soundPolicy: .silent)
        let player = StrumPatternPlayer(clock: clock ?? BeatClock())
        let coordinator = PlaySessionCoordinator(audioEngine: engine)

        coordinator.setSources(
            mode: .chordPractice,
            fingering: ManualFingeringSource(state: fingeringState),
            strum: AutoStrumSource(player: player)
        )

        self.engine = engine
        self.fingeringState = fingeringState
        self.player = player
        self.coordinator = coordinator

        // ★ 정답일 때만 소리 — 지금 짚은 운지가 목표와 맞을 때만 게이트를 연다.
        // `ChordJudge.matches`는 짚는 자리만 비교하고 뮤트↔개방은 관대하게 본다 (ChordJudge.swift).
        coordinator.soundGate = { [weak self] fingering in
            guard let self, let target = self.target else { return true }
            return ChordJudge.matches(played: fingering.frets, target: target.fingering.frets)
        }

        // 실제로 울릴 줄은 **목표 코드의 보이싱**으로 정한다 — 안 치는 줄(뮤트 X)은 소리도
        // 줄 떨림도 나지 않는다. 짚기 자체가 무음이라 자유 개방현이 섞일 일도 없다.
        coordinator.voicingOverride = { [weak self] in self?.target?.fingering }
    }

    // MARK: - 수명주기

    func startEngine() { engine?.start() }

    /// 자동 주법을 시작한다. 화면 진입 시 부른다 (모드 A처럼 재생 버튼이 아니라 진입 시 자동으로 돈다).
    func play(pattern: StrumPattern, bpm: Double? = nil) {
        player.bpmOverride = bpm
        player.play(pattern: pattern, looping: true)
    }

    func stopPlaying() { player.stop() }

    func end() {
        player.stop()
        coordinator.stop()
        fingeringState.releaseAll()
        engine?.stop()
    }
}
