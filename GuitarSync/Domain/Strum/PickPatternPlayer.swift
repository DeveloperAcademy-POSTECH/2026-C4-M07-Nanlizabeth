import Combine
import Foundation

/// 피킹 패턴을 박자 클럭에 맞춰 자동으로 뜯는 플레이어. **코드 드릴의 자동 오른손.**
///
/// `StrumPatternPlayer`와 같은 자리에 꽂힌다 — `StrumSourceProtocol`이라 코디네이터(§3.7)가
/// 그대로 받는다. 다른 점은 **줄을 하나씩** 튕겨(`pluckOccurred`) 아르페지오·베이스-스트럼을
/// 만든다는 것. 지금 무슨 코드인지는 몰라도 된다 — 코디네이터가 그 순간의 운지로 소리 낸다.
///
/// 베이스(`.bass`)는 줄 번호 `-1`로 방송하고, 코디네이터가 **그 코드의 가장 낮은 울리는 줄**로
/// 풀어 준다 (코드마다 베이스 줄이 다르므로).
@MainActor
final class PickPatternPlayer: StrumSourceProtocol {
    var strumOccurred: AnyPublisher<StrumOccurrence, Never> { strumSubject.eraseToAnyPublisher() }
    var pluckOccurred: AnyPublisher<PluckOccurrence, Never> { pluckSubject.eraseToAnyPublisher() }

    /// 사용자가 BPM을 직접 정했을 때. `nil`이면 패턴 권장값.
    var bpmOverride: Double?

    private let clock: BeatClockProtocol
    private let strumSubject = PassthroughSubject<StrumOccurrence, Never>()
    private let pluckSubject = PassthroughSubject<PluckOccurrence, Never>()
    private var clockSubscription: AnyCancellable?

    private var pattern: PickPattern?
    private var looping = false

    /// 베이스를 "가장 낮은 울리는 줄"로 풀어 달라는 신호.
    static let bassStringSentinel = -1

    init(clock: BeatClockProtocol? = nil) {
        self.clock = clock ?? BeatClock()
    }

    func play(_ pattern: PickPattern, looping: Bool = true) {
        stop()
        self.pattern = pattern
        self.looping = looping

        clockSubscription = clock.beats.sink { [weak self] event in
            self?.handleTick(event)
        }
        clock.start(bpm: bpmOverride ?? pattern.recommendedBPM, timeSignature: pattern.timeSignature)
    }

    func stop() {
        clock.stop()
        clockSubscription = nil
    }

    // MARK: - 내부

    private func handleTick(_ event: BeatEvent) {
        guard let pattern else { return }
        // 스텝은 `stepTicks`마다 하나씩만 소비한다. 그 사이 틱은 흘려보낸다.
        guard event.tickIndex % pattern.stepTicks == 0 else { return }

        let stepIndex = (event.tickIndex / pattern.stepTicks) % pattern.steps.count
        emit(pattern.steps[stepIndex])

        // 한 번만 재생이면 마지막 스텝을 낸 직후 멈춘다.
        if !looping, event.tickIndex >= pattern.loopLengthInTicks - pattern.stepTicks {
            stop()
        }
    }

    private func emit(_ step: PickPattern.Step) {
        switch step {
        case .bass:
            pluckSubject.send(PluckOccurrence(stringIndex: Self.bassStringSentinel, velocity: 104))
        case let .pluck(stringIndex):
            pluckSubject.send(PluckOccurrence(stringIndex: stringIndex, velocity: 84))
        case .strum:
            strumSubject.send(StrumOccurrence(direction: .down, velocity: 96))
        case .rest:
            break
        }
    }
}
