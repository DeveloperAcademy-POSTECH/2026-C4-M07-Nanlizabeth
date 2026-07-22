import Foundation

/// **피킹 패턴** — 코드를 통째로 긁는 대신 줄을 정해진 순서로 하나씩 튕긴다. (docs/PLAN-chord-drill 확장)
///
/// 노래마다 이 패턴을 정해두면, 정답 코드를 짚었을 때 그 순서대로 소리가 나 아르페지오·베이스-스트럼
/// 처럼 들린다. 각 스텝은 클럭의 **일정 간격(`stepTicks`)**마다 하나씩 소비된다.
struct PickPattern: Equatable {
    /// 한 스텝이 무엇을 울리는가.
    enum Step: Equatable {
        /// **베이스** — 지금 코드에서 가장 낮은(굵은) 울리는 줄. 코드마다 자동으로 달라진다.
        case bass
        /// 특정 줄 하나. `0`=6번줄(저음)…`5`=1번줄(고음).
        case pluck(Int)
        /// 6줄 전체를 아래로 긁기.
        case strum
        /// 쉼 — 아무것도 안 울린다.
        case rest
    }

    let steps: [Step]
    /// 스텝 하나의 길이(16분음표 틱 수). `2`=8분음표, `4`=4분음표.
    let stepTicks: Int
    let timeSignature: TimeSignature
    let recommendedBPM: Double

    /// 한 바퀴 길이(틱).
    var loopLengthInTicks: Int { max(steps.count * stepTicks, 1) }
}

extension PickPattern {
    /// 베이스 → 위로 뜯는 아르페지오 (4/4, 8분음표). 잔잔한 곡·기타곡에 두루 어울린다.
    static let arpeggioUp = PickPattern(
        steps: [.bass, .pluck(3), .pluck(4), .pluck(5), .bass, .pluck(3), .pluck(4), .pluck(5)],
        stepTicks: 2,
        timeSignature: .fourFour,
        recommendedBPM: 96
    )

    /// 베이스-스트럼 "쿵짝" (4/4, 4분음표). 동요에 딱 맞는 또렷한 리듬.
    static let bassStrum = PickPattern(
        steps: [.bass, .strum, .bass, .strum],
        stepTicks: 4,
        timeSignature: .fourFour,
        recommendedBPM: 96
    )

    /// 왈츠 "쿵짝짝" (3/4, 4분음표). 3박자 곡(Amazing Grace 등)에.
    static let waltz = PickPattern(
        steps: [.bass, .strum, .strum],
        stepTicks: 4,
        timeSignature: .threeFour,
        recommendedBPM: 120
    )
}
