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
        emit(pattern.steps[stepIndex], at: stepIndex, in: pattern)

        // 한 번만 재생이면 마지막 스텝을 낸 직후 멈춘다.
        if !looping, event.tickIndex >= pattern.loopLengthInTicks - pattern.stepTicks {
            stop()
        }
    }

    private func emit(_ step: PickPattern.Step, at stepIndex: Int, in pattern: PickPattern) {
        let performance = performance(for: step, at: stepIndex, in: pattern)

        switch step {
        case .bass:
            pluckSubject.send(PluckOccurrence(stringIndex: Self.bassStringSentinel, velocity: performance.velocity))
        case let .pluck(stringIndex):
            pluckSubject.send(PluckOccurrence(stringIndex: stringIndex, velocity: performance.velocity))
        case .strum:
            strumSubject.send(StrumOccurrence(direction: .down, velocity: performance.velocity, interval: performance.interval))
        case .upStrum:
            strumSubject.send(StrumOccurrence(direction: .up, velocity: performance.velocity, interval: performance.interval))
        case let .mutedStrum(direction):
            strumSubject.send(
                StrumOccurrence(
                    direction: direction,
                    velocity: performance.velocity,
                    interval: performance.interval,
                    isMute: true
                )
            )
        case .rest:
            break
        }
    }

    private struct StepPerformance {
        let velocity: UInt8
        let interval: TimeInterval
    }

    private func performance(for step: PickPattern.Step, at stepIndex: Int, in pattern: PickPattern) -> StepPerformance {
        if pattern == .youAndIFrontHalf {
            let velocities: [UInt8] = [92, 0, 0, 0, 114, 0, 76, 64]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 4)
            )
        }

        if pattern == .youAndIBackHalf {
            let velocities: [UInt8] = [0, 62, 92, 0, 116, 0, 78, 66]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 4)
            )
        }

        if pattern == .youAndIFullBar {
            let velocities: [UInt8] = [102, 0, 0, 0, 112, 0, 74, 62, 0, 60, 86, 0, 114, 0, 76, 64]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 4 || stepIndex == 12)
            )
        }

        if pattern == .springCountryShuffle {
            let velocities: [UInt8] = [112, 0, 0, 0, 0, 0, 0, 66, 98, 0, 0, 0, 106, 0, 0, 72]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 0 || stepIndex == 12)
            )
        }

        if pattern == .butterflyVerseRock {
            let velocities: [UInt8] = [106, 68, 84, 66, 102, 70, 88, 72]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 0 || stepIndex == 4)
            )
        }

        if pattern == .butterflyChorusCalypso {
            let velocities: [UInt8] = [116, 0, 94, 70, 0, 66, 106, 76]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 0 || stepIndex == 6)
            )
        }

        if pattern == .loveSongArpeggio {
            let velocities: [UInt8] = [102, 72, 78, 70, 94, 68, 76, 66]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 0 || stepIndex == 4)
            )
        }

        if pattern == .skyHalfBarDrive {
            let velocities: [UInt8] = [116, 92, 66, 104, 74, 60, 96, 72]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 0 || stepIndex == 3 || stepIndex == 6)
            )
        }

        if pattern == .skyHalfBarLift {
            let velocities: [UInt8] = [108, 68, 86, 74, 96, 62, 82, 78]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 0 || stepIndex == 4)
            )
        }

        if pattern == .sixteenBeatGoGo {
            let velocities: [UInt8] = [112, 72, 58, 82, 94, 68, 54, 80, 106, 72, 58, 84, 96, 70, 56, 86]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex % 4 == 0)
            )
        }

        if pattern == .mutedUpbeatKPopStrum {
            let velocities: [UInt8] = [70, 0, 112, 84, 62, 80, 98, 86]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 2 || stepIndex == 6)
            )
        }

        if pattern == .upbeatKPopStrum {
            let velocities: [UInt8] = [116, 0, 92, 82, 60, 80, 102, 86]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 0 || stepIndex == 6)
            )
        }

        if pattern == .miryangArirang {
            let velocities: [UInt8] = [114, 96, 66, 102, 70, 88]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 0 || stepIndex == 3)
            )
        }

        if pattern == .dorajiTaryeong {
            let velocities: [UInt8] = [108, 0, 92, 62, 86, 68]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 0 || stepIndex == 2)
            )
        }

        if pattern == .gunbamTaryeong {
            let velocities: [UInt8] = [118, 102, 68, 92, 64, 98, 72, 88]
            return StepPerformance(
                velocity: velocities[stepIndex % velocities.count],
                interval: interval(for: step, strong: stepIndex == 0 || stepIndex == 4)
            )
        }

        switch step {
        case .bass:
            return StepPerformance(velocity: stepIndex == 0 ? 108 : 96, interval: 0.018)
        case .pluck:
            return StepPerformance(velocity: 78, interval: 0.014)
        case .strum:
            return StepPerformance(velocity: stepIndex == 0 ? 108 : 88, interval: 0.026)
        case .upStrum:
            return StepPerformance(velocity: 78, interval: 0.018)
        case .mutedStrum:
            return StepPerformance(velocity: 58, interval: 0.01)
        case .rest:
            return StepPerformance(velocity: 0, interval: 0.018)
        }
    }

    private func interval(for step: PickPattern.Step, strong: Bool) -> TimeInterval {
        switch step {
        case .strum:
            return strong ? 0.024 : 0.018
        case .upStrum:
            return 0.012
        case .mutedStrum:
            return 0.008
        case .bass, .pluck:
            return 0.012
        case .rest:
            return 0.018
        }
    }
}
