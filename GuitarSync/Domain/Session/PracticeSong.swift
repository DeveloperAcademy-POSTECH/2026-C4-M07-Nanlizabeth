import Foundation

/// 코드 드릴로 연습할 **노래 하나** — 이름 + 난이도 + 코드 진행. (docs/PLAN-chord-drill 확장)
///
/// 드릴은 이 진행을 순서대로 출제한다. 진행에 쓰는 코드는 **반드시 `ChordCatalog`에 있는 것**이어야
/// 넥에 목표·손가락 안내가 뜬다 (현재 카탈로그: C·D·E·G·A·Am·Em·F).
struct PracticeSong: Identifiable, Equatable {
    /// 화면에 보이는 곡 이름.
    let title: String
    /// 난이도 라벨 ("입문" · "초급" · "중급").
    let level: String
    /// 순서대로 출제할 코드 진행.
    let chords: [GuitarChord]
    /// **튕기는 순서(피킹 패턴).** 정답 코드일 때 이 순서대로 소리가 난다 — 노래마다 다른 리듬·느낌.
    let pick: PickPattern

    init(title: String, level: String, chords: [GuitarChord], pick: PickPattern = .bassStrum) {
        self.title = title
        self.level = level
        self.chords = chords
        self.pick = pick
    }

    var id: String { title }

    /// 진행에 나오는 코드들 (순서 유지, 중복 제거) — 카드 미리보기용.
    var uniqueChords: [GuitarChord] {
        var seen = Set<GuitarChord>()
        return chords.filter { seen.insert($0).inserted }
    }

    /// 이 노래로 만든 드릴. 비어 있으면 안전하게 머니코드로 대체.
    var drill: ChordDrill { ChordDrill(chords: chords) ?? .moneyChords }
}
