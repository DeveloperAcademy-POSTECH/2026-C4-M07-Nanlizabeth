import Combine
import Foundation

// MARK: - 모델

/// 긁는 세기. 리듬의 강약을 표현한다.
enum StrumAccent: String, Codable, CaseIterable {
    case strong
    case medium
    case soft

    /// 실제 발음 세기(0~127)로 환산.
    var velocity: UInt8 {
        switch self {
        case .strong: return 112
        case .medium: return 92
        case .soft: return 68
        }
    }

    var displayName: String {
        switch self {
        case .strong: return "강"
        case .medium: return "중"
        case .soft: return "약"
        }
    }
}

/// 주법의 한 획. "몇 박째에, 어느 방향으로, 얼마나 세게 긁나".
struct StrumStep: Equatable, Codable, Identifiable {
    var id: UUID = UUID()
    /// 마디 안 위치 (16분음표 단위).
    var position: BeatPosition
    var direction: StrumDirection
    var accent: StrumAccent
    /// 뮤트 스트로크(줄을 손날로 죽이며 긁기)인가.
    var isMute: Bool

    init(
        id: UUID = UUID(),
        position: BeatPosition,
        direction: StrumDirection,
        accent: StrumAccent = .medium,
        isMute: Bool = false
    ) {
        self.id = id
        self.position = position
        self.direction = direction
        self.accent = accent
        self.isMute = isMute
    }

    /// 데이터 표를 짧게 적기 위한 편의 생성자.
    ///
    /// ```swift
    /// StrumStep(beat: 0, sub: 0, .down, .strong)   // 1박 정박, 다운, 세게
    /// StrumStep(beat: 1, sub: 2, .up)              // 2박 뒤쪽 8분음표, 업
    /// ```
    init(
        bar: Int = 0,
        beat: Int,
        sub: Int = 0,
        _ direction: StrumDirection,
        _ accent: StrumAccent = .medium,
        mute: Bool = false
    ) {
        self.init(
            position: BeatPosition(bar: bar, beat: beat, sub: sub),
            direction: direction,
            accent: accent,
            isMute: mute
        )
    }
}

/// 프리셋인가 사용자가 만든 것인가.
enum PatternSource: String, Codable {
    case preset
    case custom
}

/// 주법(리듬 패턴) 하나. **이 모양만 지키면 어떤 리듬이든 꽂힌다.** (ARCHITECTURE §3.5)
struct StrumPattern: Equatable, Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var timeSignature: TimeSignature
    var steps: [StrumStep]
    var source: PatternSource
    /// 이 주법에 어울리는 권장 BPM. 미리듣기의 기본값으로 쓴다.
    ///
    /// - Note: ⚠️ 유저가 정한 BPM과 어느 쪽이 이기는지는 **SPEC §8 열린 결정**.
    var recommendedBPM: Double

    init(
        id: UUID = UUID(),
        name: String,
        timeSignature: TimeSignature = .fourFour,
        steps: [StrumStep],
        source: PatternSource = .preset,
        recommendedBPM: Double = 90
    ) {
        self.id = id
        self.name = name
        self.timeSignature = timeSignature
        self.steps = steps
        self.source = source
        self.recommendedBPM = recommendedBPM
    }

    /// 이 패턴이 몇 마디짜리인가 (가장 늦은 스텝 기준).
    var barCount: Int {
        (steps.map(\.position.bar).max() ?? 0) + 1
    }

    /// 시간순으로 정렬된 스텝.
    var orderedSteps: [StrumStep] {
        steps.sorted { $0.position < $1.position }
    }

    /// 특정 박 위치에 울려야 할 스텝들.
    func steps(at position: BeatPosition) -> [StrumStep] {
        steps.filter { $0.position == position }
    }

    /// 프리셋 목록이 비었을 때를 위한 최후 기본값 — 매 박 다운 스트로크.
    /// (`Content/StrumPresetData`가 채워져 있으면 쓸 일이 없다.)
    static let fallback = StrumPattern(
        name: "4비트 기본",
        steps: (0..<4).map { StrumStep(beat: $0, .down, $0 == 0 ? .strong : .medium) },
        recommendedBPM: 80
    )
}

// MARK: - 라이브러리 계약

/// 주법 목록을 갖고 있는 곳. (ARCHITECTURE §3.5)
///
/// - Important: **주법은 커스텀을 지원하지 않습니다** (2026-07-20 결정). 프리셋 읽기 전용입니다.
///   사용자가 직접 만드는 건 **코드진행뿐**입니다 (`ChordProgressionLibraryProtocol`).
///   초보자가 리듬을 처음부터 만드는 건 난이도가 높고, 프리셋 리서치(CT1)로 충분하다고 판단했습니다.
@MainActor
protocol StrumPatternLibraryProtocol: AnyObject {
    /// 기본 제공 주법 (`Content/StrumPresetData.swift`).
    var presets: [StrumPattern] { get }

    func pattern(id: UUID) -> StrumPattern?
}

extension StrumPatternLibraryProtocol {
    /// 선택 화면이 보여주는 목록. 주법은 프리셋이 전부다.
    var allPatterns: [StrumPattern] { presets }
}

// MARK: - 플레이어 계약

/// 패턴을 클럭에 맞춰 자동으로 긁는다. **모드 A의 "자동 오른손".** (ARCHITECTURE §3.5)
///
/// 소리를 내는 데 필요한 **운지는 자기가 모른다** — 코디네이터(§3.7)가 그 순간의 운지를 물려준다.
@MainActor
protocol StrumPatternPlayerProtocol: AnyObject {
    var isPlaying: Bool { get }
    var currentPattern: StrumPattern? { get }
    /// 한 획을 그을 때마다 방송. UI 표시·햅틱이 구독한다.
    var strumPerformed: AnyPublisher<StrumPerformedEvent, Never> { get }

    func play(pattern: StrumPattern, looping: Bool)
    func stop()
}

/// "지금 이렇게 긁었다" 방송.
struct StrumPerformedEvent: Equatable {
    let direction: StrumDirection
    let velocity: UInt8
    let isMute: Bool
    /// 이 획이 패턴의 몇 번째 스텝이었나 (UI에서 현재 위치 표시용).
    let step: StrumStep
}

// MARK: - Mock

/// 하드코딩 프리셋 3개를 돌려주는 가짜 라이브러리. (ARCHITECTURE §4.1)
///
/// **스트로크 선택 화면(U4)을 진짜 데이터 없이 완성할 수 있게** 한다.
@MainActor
final class MockStrumPatternLibrary: StrumPatternLibraryProtocol, ObservableObject {
    let presets: [StrumPattern]

    init(presets: [StrumPattern]? = nil) {
        self.presets = presets ?? Self.stubPresets
    }

    func pattern(id: UUID) -> StrumPattern? {
        allPatterns.first { $0.id == id }
    }

    /// 화면 개발용 가짜 프리셋 3개. 진짜 데이터는 CT1이 `Content/`에 채운다.
    static let stubPresets: [StrumPattern] = [
        StrumPattern(
            name: "4비트 기본",
            steps: (0..<4).map { StrumStep(beat: $0, .down, $0 == 0 ? .strong : .medium) },
            recommendedBPM: 80
        ),
        StrumPattern(
            name: "8비트",
            steps: (0..<4).flatMap { beat in
                [
                    StrumStep(beat: beat, sub: 0, .down, beat == 0 ? .strong : .medium),
                    StrumStep(beat: beat, sub: 2, .up, .soft),
                ]
            },
            recommendedBPM: 100
        ),
        StrumPattern(
            name: "칼립소",
            steps: [
                StrumStep(beat: 0, sub: 0, .down, .strong),
                StrumStep(beat: 1, sub: 2, .down, .medium),
                StrumStep(beat: 2, sub: 0, .up, .soft),
                StrumStep(beat: 2, sub: 2, .up, .soft),
                StrumStep(beat: 3, sub: 0, .down, .medium),
                StrumStep(beat: 3, sub: 2, .up, .soft),
            ],
            recommendedBPM: 110
        ),
    ]
}

/// 아무 소리도 안 내고 "긁었다"고 방송만 하는 가짜 플레이어. (ARCHITECTURE §4.1)
///
/// 스트럼 화면의 표시·햅틱을 오디오 없이 개발할 때 쓴다.
@MainActor
final class MockStrumPatternPlayer: StrumPatternPlayerProtocol, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentPattern: StrumPattern?

    var strumPerformed: AnyPublisher<StrumPerformedEvent, Never> { subject.eraseToAnyPublisher() }

    private let subject = PassthroughSubject<StrumPerformedEvent, Never>()

    func play(pattern: StrumPattern, looping: Bool) {
        currentPattern = pattern
        isPlaying = true
    }

    func stop() {
        isPlaying = false
    }

    /// 테스트·프리뷰에서 손으로 한 획 발생시킨다.
    func emit(_ step: StrumStep) {
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
