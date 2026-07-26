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
        /// 6줄 전체를 위로 긁기.
        case upStrum
        /// 오른손 날로 줄을 막아 박자만 찍는 뮤트 스트럼.
        case mutedStrum(StrumDirection)
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

    /// 신나는 가요 기본 스트로크. 다운-다운-업-다운-업-다운-업.
    static let upbeatKPopStrum = PickPattern(
        steps: [.strum, .rest, .strum, .upStrum, .strum, .upStrum, .strum, .upStrum],
        stepTicks: 2,
        timeSignature: .fourFour,
        recommendedBPM: 158
    )

    /// 초반부 브레이크감을 주는 쉼 포함 스트로크.
    static let mutedUpbeatKPopStrum = PickPattern(
        steps: [.strum, .rest, .strum, .upStrum, .rest, .upStrum, .strum, .upStrum],
        stepTicks: 2,
        timeSignature: .fourFour,
        recommendedBPM: 158
    )

    /// 빠른 16비트 고고/16분음표 리듬 스트로크.
    static let sixteenBeatGoGo = PickPattern(
        steps: [
            .strum, .upStrum, .strum, .upStrum,
            .strum, .upStrum, .strum, .upStrum,
            .strum, .upStrum, .strum, .upStrum,
            .strum, .upStrum, .strum, .upStrum,
        ],
        stepTicks: 1,
        timeSignature: .fourFour,
        recommendedBPM: 117
    )

    /// 너에게 난 나에게 넌 전반 2박: D--- D-DU.
    static let youAndIFrontHalf = PickPattern(
        steps: [.strum, .rest, .rest, .rest, .strum, .rest, .strum, .upStrum],
        stepTicks: 1,
        timeSignature: .fourFour,
        recommendedBPM: 74
    )

    /// 너에게 난 나에게 넌 후반 2박: -UD- D-DU.
    static let youAndIBackHalf = PickPattern(
        steps: [.rest, .upStrum, .strum, .rest, .strum, .rest, .strum, .upStrum],
        stepTicks: 1,
        timeSignature: .fourFour,
        recommendedBPM: 74
    )

    /// 너에게 난 나에게 넌 한 마디: D--- D-DU -UD- D-DU.
    static let youAndIFullBar = PickPattern(
        steps: [
            .strum, .rest, .rest, .rest,
            .strum, .rest, .strum, .upStrum,
            .rest, .upStrum, .strum, .rest,
            .strum, .rest, .strum, .upStrum,
        ],
        stepTicks: 1,
        timeSignature: .fourFour,
        recommendedBPM: 92
    )

    /// 봄봄봄: D---U D-DU를 뒤쪽 16분음표에 배치해 셔플 바운스를 살린 한 마디.
    static let springCountryShuffle = PickPattern(
        steps: [
            .strum, .rest, .rest, .rest,
            .rest, .rest, .rest, .upStrum,
            .strum, .rest, .rest, .rest,
            .strum, .rest, .rest, .upStrum,
        ],
        stepTicks: 1,
        timeSignature: .fourFour,
        recommendedBPM: 112
    )

    /// 나는 나비 벌스: 저음 근음을 8분음표로 밀어주는 락 반주. 뮤트는 연주자가 직접 한다.
    static let butterflyVerseRock = PickPattern(
        steps: [.bass, .bass, .bass, .bass, .bass, .bass, .bass, .bass],
        stepTicks: 2,
        timeSignature: .fourFour,
        recommendedBPM: 143
    )

    /// 나는 나비 후렴: D-DU-UDU 칼립소 스트로크.
    static let butterflyChorusCalypso = PickPattern(
        steps: [.strum, .rest, .strum, .upStrum, .rest, .upStrum, .strum, .upStrum],
        stepTicks: 2,
        timeSignature: .fourFour,
        recommendedBPM: 143
    )

    /// 연가: 낮은 베이스에서 고음으로 부드럽게 올라가는 한 마디 아르페지오.
    static let loveSongArpeggio = PickPattern(
        steps: [.bass, .pluck(3), .pluck(4), .pluck(5), .bass, .pluck(3), .pluck(4), .pluck(5)],
        stepTicks: 2,
        timeSignature: .fourFour,
        recommendedBPM: 82
    )

    /// 하늘을 달리다 벌스: 다운, 다운업, 다운, 업, 업다운, 다운업 느낌의 8스트로크.
    static let skyHalfBarDrive = PickPattern(
        steps: [.strum, .strum, .upStrum, .strum, .upStrum, .upStrum, .strum, .upStrum],
        stepTicks: 1,
        timeSignature: .fourFour,
        recommendedBPM: 117
    )

    /// 하늘을 달리다 응답 마디: 뒤쪽 업스트로크가 더 살아나는 반마디.
    static let skyHalfBarLift = PickPattern(
        steps: [.strum, .upStrum, .strum, .upStrum, .strum, .upStrum, .strum, .upStrum],
        stepTicks: 1,
        timeSignature: .fourFour,
        recommendedBPM: 117
    )

    /// 하늘을 달리다 빠른 코드 전환: 한 박 단위 스트로크.
    static let skyQuarterDrive = PickPattern(
        steps: [.strum, .upStrum, .strum, .upStrum],
        stepTicks: 1,
        timeSignature: .fourFour,
        recommendedBPM: 117
    )

    /// 하늘을 달리다 엔딩/간주: 길게 걸어두는 코드.
    static let skyHold = PickPattern(
        steps: [.strum, .rest, .rest, .rest],
        stepTicks: 1,
        timeSignature: .fourFour,
        recommendedBPM: 117
    )

    /// 밀양아리랑: 3박 안에서 베이스와 다운·업이 물결치듯 이어지는 빠른 민요 반주.
    static let miryangArirang = PickPattern(
        steps: [.bass, .strum, .upStrum, .strum, .upStrum, .strum],
        stepTicks: 2,
        timeSignature: .threeFour,
        recommendedBPM: 132
    )

    /// 도라지타령: 첫 박의 베이스를 길게 두고 뒤 두 박을 가볍게 들어 올리는 세마치 느낌.
    static let dorajiTaryeong = PickPattern(
        steps: [.bass, .rest, .strum, .upStrum, .strum, .upStrum],
        stepTicks: 2,
        timeSignature: .threeFour,
        recommendedBPM: 124
    )

    /// 군밤타령: 베이스 악센트 뒤에 다운·업을 촘촘히 넣은 빠른 8비트 반주.
    static let gunbamTaryeong = PickPattern(
        steps: [.bass, .strum, .upStrum, .strum, .upStrum, .strum, .upStrum, .strum],
        stepTicks: 2,
        timeSignature: .fourFour,
        recommendedBPM: 148
    )
}
