import Combine
import Foundation

/// 코드진행을 박자 클럭에 맞춰 자동으로 짚어주는 플레이어. **모드 B의 자동 왼손.** (ROADMAP 태스크 L3)
///
/// L2(`StrumPatternPlayer`)와 대칭이다. L2가 "박마다 긁는다"면, 이쪽은 "마디마다 코드를 바꾼다".
///
/// ```
/// BeatClock ──박──▶ ChordProgressionPlayer ──(마디 바뀜)──▶ currentFingering 갱신 + chordChanged
///                                                             │
///                                    AutoFingeringSource ◀────┘ ──▶ Coordinator (오른손이 긁을 때 이 운지를 씀)
/// ```
///
/// ## 언제 코드를 바꾸나
///
/// 클럭은 16분음표마다 틱을 쏘지만, 코드는 **마디 경계**에서만 바뀐다. 그래서 틱을 마디 길이로
/// 나눠 지금 몇 마디째인지 구하고, 마디 번호가 바뀔 때만 코드를 갱신한다.
@MainActor
final class ChordProgressionPlayer: ChordProgressionPlayerProtocol, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentChord: GuitarChord?

    var currentFingering: GuitarFingering { currentChord?.fingering ?? .open }
    var chordChanged: AnyPublisher<GuitarChord, Never> { subject.eraseToAnyPublisher() }

    private let clock: BeatClockProtocol
    private let subject = PassthroughSubject<GuitarChord, Never>()
    private var clockSubscription: AnyCancellable?

    private var progression: ChordProgression?
    private var looping = false
    private var subdivisionsPerBar = 0
    /// 지금까지 반영한 마디 번호. 틱이 이 마디를 넘어설 때만 코드를 갱신한다.
    private var currentBar = -1

    init(clock: BeatClockProtocol? = nil) {
        self.clock = clock ?? BeatClock()
    }

    func start(progression: ChordProgression, bpm: Double, looping: Bool) {
        stop()
        guard progression.totalBars > 0 else { return }

        self.progression = progression
        self.looping = looping
        // 진행은 박자표를 따로 안 갖는다 — 마디 단위 개념이라 4/4로 센다.
        self.subdivisionsPerBar = TimeSignature.fourFour.subdivisionsPerBar
        self.currentBar = -1

        clockSubscription = clock.beats
            .sink { [weak self] event in self?.handleTick(event) }

        isPlaying = true
        clock.start(bpm: bpm, timeSignature: .fourFour)
    }

    func stop() {
        clock.stop()
        clockSubscription = nil
        isPlaying = false
        currentChord = nil
        currentBar = -1
    }

    // MARK: - 내부

    private func handleTick(_ event: BeatEvent) {
        guard let progression else { return }

        let bar = event.tickIndex / max(subdivisionsPerBar, 1)

        // 한 번만 재생인데 진행 끝을 넘어섰으면 멈춘다.
        if !looping, bar >= progression.totalBars {
            stop()
            return
        }

        guard bar != currentBar else { return }   // 아직 같은 마디면 코드 유지
        currentBar = bar

        guard let chord = progression.loopedChord(atBar: bar), chord != currentChord else { return }
        currentChord = chord
        subject.send(chord)
    }
}
