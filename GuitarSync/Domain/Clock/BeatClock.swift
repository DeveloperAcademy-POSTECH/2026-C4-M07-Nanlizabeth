import Combine
import Foundation

// MARK: - 박자 좌표

/// 박자표. `(beatsPerBar: 4, noteValue: 4)` = 4/4박자.
struct TimeSignature: Equatable, Codable {
    var beatsPerBar: Int
    var noteValue: Int

    static let fourFour = TimeSignature(beatsPerBar: 4, noteValue: 4)
    static let threeFour = TimeSignature(beatsPerBar: 3, noteValue: 4)

    /// 한 마디에 들어가는 16분음표 개수.
    var subdivisionsPerBar: Int { beatsPerBar * BeatPosition.subdivisionsPerBeat }
}

/// 마디 안에서의 위치. **전 팀 공통 규약** (ARCHITECTURE §5).
///
/// - `bar`: 0부터 · `beat`: 0부터 · `sub`: 16분음표 0~3
/// - 예) 2마디 3박 뒤쪽 8분음표 = `BeatPosition(bar: 1, beat: 2, sub: 2)`
struct BeatPosition: Equatable, Codable, Comparable, Hashable {
    /// 한 박을 몇 등분해서 방송하는가 (16분음표 = 4등분).
    static let subdivisionsPerBeat = 4

    var bar: Int
    var beat: Int
    var sub: Int

    init(bar: Int = 0, beat: Int = 0, sub: Int = 0) {
        self.bar = bar
        self.beat = beat
        self.sub = sub
    }

    /// 시작부터 센 절대 16분음표 번호 → 마디/박/16분음표 위치.
    static func at(tick: Int, timeSignature: TimeSignature) -> BeatPosition {
        let perBar = max(timeSignature.subdivisionsPerBar, 1)
        let safeTick = max(tick, 0)
        return BeatPosition(
            bar: safeTick / perBar,
            beat: (safeTick % perBar) / subdivisionsPerBeat,
            sub: safeTick % subdivisionsPerBeat
        )
    }

    /// 위 변환의 역방향. 패턴 스텝을 시간순으로 정렬할 때 쓴다.
    func tickIndex(in timeSignature: TimeSignature) -> Int {
        bar * timeSignature.subdivisionsPerBar
            + beat * Self.subdivisionsPerBeat
            + sub
    }

    static func < (lhs: BeatPosition, rhs: BeatPosition) -> Bool {
        (lhs.bar, lhs.beat, lhs.sub) < (rhs.bar, rhs.beat, rhs.sub)
    }
}

/// 클럭이 16분음표마다 방송하는 알림.
struct BeatEvent: Equatable {
    /// 지금 어디인가.
    var position: BeatPosition
    /// 시작부터 몇 번째 16분음표인가 (0부터). 루프 횟수 계산 등에 쓴다.
    var tickIndex: Int
    /// 이 틱이 **울렸어야 할** 시각 (클럭 시작 기준 경과 초).
    ///
    /// 실제 호출은 이보다 조금 늦을 수 있다. 정밀한 스케줄링이 필요한 소비자는
    /// 이 값으로 지연분을 보정한다.
    var scheduledTime: TimeInterval

    /// 박의 첫 16분음표인가 (♩ 단위).
    var isBeat: Bool { position.sub == 0 }
    /// 마디의 첫 박인가 (강박).
    var isDownbeat: Bool { isBeat && position.beat == 0 }
}

// MARK: - 계약

/// BPM에 맞춰 "지금 몇 마디 몇 박 몇 번째 16분음표"를 계속 방송하는 박자 심장.
/// (ARCHITECTURE §3.2)
///
/// 자동 스트럼·자동 코드진행·미리듣기가 **전부 이 하나에 맞춰** 움직인다.
///
/// ```swift
/// let clock: BeatClockProtocol = BeatClock()
/// cancellable = clock.beats
///     .filter(\.isBeat)                       // ♩ 단위만 받고 싶다면
///     .sink { event in print(event.position) }
/// clock.start(bpm: 90, timeSignature: .fourFour)
/// ```
@MainActor
protocol BeatClockProtocol: AnyObject {
    var isRunning: Bool { get }
    var currentBPM: Double { get }
    var timeSignature: TimeSignature { get }

    /// 16분음표마다 방송되는 박 이벤트.
    var beats: AnyPublisher<BeatEvent, Never> { get }

    func start(bpm: Double, timeSignature: TimeSignature)
    func stop()
}

extension BeatClockProtocol {
    /// 박자표를 생략하면 4/4.
    func start(bpm: Double) {
        start(bpm: bpm, timeSignature: .fourFour)
    }
}

// MARK: - 기본 구현

/// `DispatchSourceTimer` 기반 박자 클럭.
///
/// **왜 `Timer`를 안 쓰나:** `Timer`는 런루프 상황에 따라 밀리고, 밀린 만큼이 **누적**된다.
/// 여기서는 두 가지로 드리프트를 막는다.
/// 1. GCD 반복 타이머는 최초 deadline 기준으로 `deadline + n×interval` 시점에 발화한다 —
///    한 번 늦어도 다음 발화 시각이 앞당겨져 **누적되지 않는다.**
/// 2. 음악적 위치는 시계가 아니라 **틱 카운터**에서 계산한다 — 발화가 늦어도 위치는 정확하다.
///
/// - Note: 그래도 이건 UI 타이머 수준의 정확도다. 더 촘촘한 정확도가 필요하면
///   오디오 엔진 자체 클럭(`AVAudioTime` 샘플 단위 스케줄링)으로 올라가야 한다.
///   전환 여부는 실기기 검증 후 결정 (ARCHITECTURE §3.2의 열린 리스크).
@MainActor
final class BeatClock: BeatClockProtocol, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var currentBPM: Double = 90
    private(set) var timeSignature: TimeSignature = .fourFour

    var beats: AnyPublisher<BeatEvent, Never> { beatSubject.eraseToAnyPublisher() }

    private let beatSubject = PassthroughSubject<BeatEvent, Never>()
    private let queue = DispatchQueue(label: "com.guitarsync.beatclock", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var tickIndex = 0
    private var tickInterval: TimeInterval = 0

    func start(bpm: Double, timeSignature: TimeSignature) {
        stop()

        let safeBPM = max(bpm, 1)
        currentBPM = safeBPM
        self.timeSignature = timeSignature
        tickInterval = 60.0 / safeBPM / Double(BeatPosition.subdivisionsPerBeat)
        tickIndex = 0

        let timer = DispatchSource.makeTimerSource(queue: queue)
        // deadline을 now로 잡아 첫 틱이 즉시 울리게 한다 (연주 시작 = 1박째).
        timer.schedule(deadline: .now(), repeating: tickInterval, leeway: .nanoseconds(0))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in self?.fireTick() }
        }
        self.timer = timer
        isRunning = true
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        tickIndex = 0
        isRunning = false
    }

    private func fireTick() {
        guard isRunning else { return }

        let event = BeatEvent(
            position: BeatPosition.at(tick: tickIndex, timeSignature: timeSignature),
            tickIndex: tickIndex,
            scheduledTime: Double(tickIndex) * tickInterval
        )
        tickIndex += 1
        beatSubject.send(event)
    }

    deinit {
        timer?.cancel()
    }
}

// MARK: - Mock

/// 손으로 박을 넘기는 가짜 클럭. (ARCHITECTURE §4.1 Mock 규칙)
///
/// 실제 시간이 흐르지 않으므로 **테스트와 UI 개발에 쓴다** — 원하는 시점에 원하는 박을 만들 수 있다.
///
/// ```swift
/// let clock = MockBeatClock()
/// player.play(pattern: pattern, clock: clock)
/// clock.advance(by: 4)      // 1박 진행 (16분음표 4개)
/// clock.advanceBars(1)      // 1마디 진행
/// ```
@MainActor
final class MockBeatClock: BeatClockProtocol {
    private(set) var isRunning = false
    private(set) var currentBPM: Double = 90
    private(set) var timeSignature: TimeSignature = .fourFour

    var beats: AnyPublisher<BeatEvent, Never> { beatSubject.eraseToAnyPublisher() }

    /// 지금까지 방송한 이벤트 기록 (테스트 검증용).
    private(set) var emitted: [BeatEvent] = []

    private let beatSubject = PassthroughSubject<BeatEvent, Never>()
    private var tickIndex = 0

    func start(bpm: Double, timeSignature: TimeSignature) {
        currentBPM = max(bpm, 1)
        self.timeSignature = timeSignature
        tickIndex = 0
        emitted.removeAll()
        isRunning = true
    }

    func stop() {
        isRunning = false
        tickIndex = 0
    }

    /// 16분음표 `count`개만큼 박을 넘긴다.
    func advance(by count: Int = 1) {
        guard isRunning else { return }
        for _ in 0..<max(count, 0) {
            let event = BeatEvent(
                position: BeatPosition.at(tick: tickIndex, timeSignature: timeSignature),
                tickIndex: tickIndex,
                scheduledTime: Double(tickIndex) * (60.0 / currentBPM / Double(BeatPosition.subdivisionsPerBeat))
            )
            tickIndex += 1
            emitted.append(event)
            beatSubject.send(event)
        }
    }

    /// 마디 단위로 넘긴다.
    func advanceBars(_ bars: Int) {
        advance(by: bars * timeSignature.subdivisionsPerBar)
    }
}
