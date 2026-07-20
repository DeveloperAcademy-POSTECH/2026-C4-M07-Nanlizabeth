import Combine
import Foundation

/// 모드 B(스트로크 연습)를 통째로 조립한 세션. (ROADMAP 태스크 I2 · SPEC §2 모드 B)
///
/// **왼손은 자동(코드진행), 오른손은 직접(내가 긁기).** 모드 A와 왼손/오른손이 뒤바뀐 대칭이다.
///
/// ```
///   ChordProgressionPlayer ──자동 코드──▶ AutoFingeringSource ──┐
///                                                                ▼
///   스트럼 화면 ──긁기──▶ ManualStrumSource ──▶ Coordinator ──▶ AudioEngine
/// ```
///
/// 모드 A(`ChordPracticeSession`)와 같은 코디네이터·엔진 공유 원칙을 따른다.
@MainActor
final class StrumPracticeSession: ObservableObject {
    /// 스트럼 화면이 여기에 "긁었다"를 밀어 넣는다.
    let strumSource = ManualStrumSource()

    @Published private(set) var isPlaying = false
    /// 지금 자동으로 짚혀 있는 코드 — 화면의 "현재 코드" 표시가 읽는다.
    @Published private(set) var currentChord: GuitarChord?

    /// 실제로 소리가 난 사건 — 줄 애니메이션(U3)·햅틱(H1)이 구독한다.
    var notePlayed: AnyPublisher<NotePlayedEvent, Never> { coordinator.notePlayed }

    private let engine: GuitarAudioEngineProtocol?
    private let progressionPlayer: ChordProgressionPlayer
    private let coordinator: PlaySessionCoordinator
    private var cancellables: Set<AnyCancellable> = []

    init(engine: GuitarAudioEngineProtocol?, clock: BeatClockProtocol? = nil) {
        let progressionPlayer = ChordProgressionPlayer(clock: clock ?? BeatClock())
        let coordinator = PlaySessionCoordinator(audioEngine: engine)

        // 왼손 = 자동 진행, 오른손 = 내 손(수동).
        coordinator.setSources(
            mode: .strumPractice,
            fingering: AutoFingeringSource(player: progressionPlayer),
            strum: strumSource
        )

        self.engine = engine
        self.progressionPlayer = progressionPlayer
        self.coordinator = coordinator

        // 자동으로 짚히는 코드를 화면 표시용으로 중계한다.
        progressionPlayer.chordChanged
            .sink { [weak self] chord in self?.currentChord = chord }
            .store(in: &cancellables)
    }

    func startEngine() {
        engine?.start()
    }

    /// 자동 코드진행을 시작한다. 재생(▶) 버튼이 부른다.
    func play(progression: ChordProgression, bpm: Double? = nil) {
        progressionPlayer.start(
            progression: progression,
            bpm: bpm ?? progression.recommendedBPM,
            looping: true
        )
        isPlaying = true
    }

    /// 내가 긁었다고 알린다. 스트럼 화면이 부른다.
    func strum(direction: StrumDirection, velocity: UInt8, interval: TimeInterval = 0.035) {
        strumSource.strum(direction: direction, velocity: velocity, interval: interval)
    }

    func stopPlaying() {
        progressionPlayer.stop()
        isPlaying = false
    }

    func end() {
        progressionPlayer.stop()
        coordinator.stop()
        isPlaying = false
        currentChord = nil
        engine?.stop()
    }
}
