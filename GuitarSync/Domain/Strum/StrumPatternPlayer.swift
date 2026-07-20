import Combine
import Foundation

/// 주법 하나를 박자 클럭에 맞춰 자동으로 긁는 플레이어. **모드 A의 자동 오른손.** (ROADMAP 태스크 L2)
///
/// ## 이게 어디에 꽂히나
///
/// 소리를 **직접 내지 않는다.** 박이 올 때마다 "지금 이렇게 긁었다"(`strumPerformed`)를 방송할 뿐이다.
/// 그 방송을 `AutoStrumSource`가 받아 코디네이터(§3.7)에 넘기고, 코디네이터가 그 순간의 운지로
/// 오디오를 호출한다. **그래서 이 플레이어는 지금 무슨 코드를 짚고 있는지 몰라도 된다.**
///
/// ```
/// BeatClock ──박──▶ StrumPatternPlayer ──strumPerformed──▶ AutoStrumSource
///                                                             │
///                        (그 순간의 운지) ◀── Coordinator ◀──┘ ──▶ AudioEngine
/// ```
///
/// ## 박을 스텝에 맞추는 법
///
/// 클럭은 16분음표마다 틱을 쏜다(`tickIndex` 0,1,2,…). 패턴은 마디 안 위치(`BeatPosition`)로
/// 스텝을 갖고 있으므로, **틱을 패턴 길이로 나눈 나머지**가 패턴 안 위치가 된다. 그 위치에 스텝이
/// 있으면 긁는다. 루프면 나머지가 계속 돌고, 한 번만이면 한 바퀴 돌고 멈춘다.
@MainActor
final class StrumPatternPlayer: StrumPatternPlayerProtocol, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentPattern: StrumPattern?

    var strumPerformed: AnyPublisher<StrumPerformedEvent, Never> { subject.eraseToAnyPublisher() }

    /// 사용자가 BPM을 직접 정했을 때. `nil`이면 패턴의 권장 BPM을 쓴다.
    ///
    /// - Note: ⚠️ 유저 BPM과 권장 BPM 중 무엇이 이기는지는 **SPEC §8 열린 결정**이다.
    ///   지금은 "유저가 정했으면 유저 우선"으로 두되, 결정되면 여기만 바꾸면 된다.
    var bpmOverride: Double?

    private let clock: BeatClockProtocol
    private let subject = PassthroughSubject<StrumPerformedEvent, Never>()
    private var clockSubscription: AnyCancellable?

    /// 틱 위치(패턴 안) → 그 위치에 울릴 스텝들. `play`에서 한 번 만들어 두고 매 틱 조회만 한다.
    private var stepsByTick: [Int: [StrumStep]] = [:]
    /// 패턴 한 바퀴의 길이(틱). 이걸로 나눠 패턴 안 위치를 구한다.
    private var loopLengthInTicks = 0
    private var looping = false

    /// - Parameter clock: 박자 심장. 비우면 실제 `BeatClock`, 테스트는 `MockBeatClock`을 넣는다.
    ///   기본값을 `nil`로 둔 이유: `BeatClock`은 `@MainActor`라 기본 인자 자리(비격리 문맥)에서는
    ///   만들 수 없고, 격리된 `init` 안에서 만들어야 한다.
    init(clock: BeatClockProtocol? = nil) {
        self.clock = clock ?? BeatClock()
    }

    func play(pattern: StrumPattern, looping: Bool) {
        stop()

        self.currentPattern = pattern
        self.looping = looping
        self.loopLengthInTicks = max(pattern.barCount * pattern.timeSignature.subdivisionsPerBar, 1)
        self.stepsByTick = Self.indexStepsByTick(pattern)

        clockSubscription = clock.beats
            .sink { [weak self] event in
                self?.handleTick(event)
            }

        isPlaying = true
        clock.start(
            bpm: bpmOverride ?? pattern.recommendedBPM,
            timeSignature: pattern.timeSignature
        )
    }

    func stop() {
        clock.stop()
        clockSubscription = nil
        isPlaying = false
    }

    // MARK: - 내부

    private func handleTick(_ event: BeatEvent) {
        let tickInLoop = event.tickIndex % loopLengthInTicks

        if let steps = stepsByTick[tickInLoop] {
            for step in steps {
                subject.send(
                    StrumPerformedEvent(
                        direction: step.direction,
                        velocity: step.accent.velocity,
                        isMute: step.isMute,
                        step: step
                    )
                )
            }
        }

        // 한 번만 재생이면 **패턴의 마지막 틱을 처리한 직후** 멈춘다.
        // "다음 틱이 오면 멈춘다"로 두면, 마지막 획과 정지 사이가 한 틱 비고,
        // 클럭이 멈춰 다음 틱이 안 오는 경우 영영 안 멈춘다.
        if !looping, event.tickIndex >= loopLengthInTicks - 1 {
            stop()
        }
    }

    /// 스텝들을 "패턴 안 틱 위치"로 묶는다. 한 위치에 여러 스텝이 있을 수 있어 배열로 담는다.
    private static func indexStepsByTick(_ pattern: StrumPattern) -> [Int: [StrumStep]] {
        Dictionary(grouping: pattern.steps) { step in
            step.position.tickIndex(in: pattern.timeSignature)
        }
    }
}
