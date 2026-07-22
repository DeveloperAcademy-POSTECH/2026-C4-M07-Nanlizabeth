import Foundation

/// 코드 전환 드릴의 진행 상태 — 정해둔 코드 시퀀스를 순서대로 돈다. (docs/PLAN-chord-drill §4-2)
///
/// 목표 코드를 하나 제시하고, 맞히면 `advance()`로 다음 코드로 넘어간다. 끝까지 가면 처음으로 루프한다.
/// **순수 값 타입이라 화면·소리 없이 유닛테스트로 검증된다.**
struct ChordDrill: Equatable {
    /// 순서대로 출제할 코드들. 비어 있으면 만들 수 없다.
    let chords: [GuitarChord]
    /// 지금 출제 중인 코드의 위치 (0-based).
    private(set) var index: Int

    init?(chords: [GuitarChord], startIndex: Int = 0) {
        guard !chords.isEmpty else { return nil }
        self.chords = chords
        self.index = ((startIndex % chords.count) + chords.count) % chords.count
    }

    /// 지금 맞혀야 할 코드.
    var current: GuitarChord { chords[index] }
    /// 진행 위치 (0-based).
    var position: Int { index }
    /// 전체 코드 개수.
    var total: Int { chords.count }

    /// 다음 코드로. 마지막이면 처음으로 돌아온다.
    mutating func advance() {
        index = (index + 1) % chords.count
    }
}

extension ChordDrill {
    /// 기본 드릴 — 머니코드 C→G→Am→F. 현재 카탈로그 8개 코드로 전부 커버된다.
    static let moneyChords = ChordDrill(chords: ["C", "G", "Am", "F"])!
}
