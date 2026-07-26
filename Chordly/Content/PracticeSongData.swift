/// 코드 드릴 연습곡 목록. (docs/PLAN-chord-drill 확장)
///
/// ## 고른 기준
///
/// 초보자가 개방 코드 중심으로 완주할 수 있고, 통기타 반주가 잘 어울리는 익숙한 한국 노래를 고른다.
///
/// ## 채우는 법
///
/// 아래에 한 줄 추가하면 노래 선택 화면과 드릴에 바로 나타난다. **코드는 `ChordCatalog`에 있는
/// 것만** 쓴다 (현재: C·C7·D·D7·Dm·Dm7·E·G·G7·A·Aadd9·Am·Bm·Dadd9·Em·F·Fmaj7·Bsus4·C#m7·F#sus4·F#7sus4).
enum PracticeSongData {
    static let songs: [PracticeSong] = [
        PracticeSong(
            title: "봄봄봄",
            level: "초급 · 컨트리 셔플",
            chords: [
                "C", "G", "Am", "E7", "F", "G7", "C", "C",
                "C", "G", "Am", "E7", "F", "G7", "C", "C",
                "C", "G", "Am", "E7", "F", "G7", "C", "C",
                "C", "G", "Am", "E7", "F", "G7", "C", "C",
            ],
            pick: .springCountryShuffle,
            lyricBars: [
                "인트로", "", "", "", "", "", "", "",
                "1절", "", "", "", "", "", "", "",
                "프리 코러스", "", "", "", "", "", "", "",
                "후렴", "", "", "", "", "", "", "",
            ]
        ),
        PracticeSong(
            title: "나는 나비",
            level: "초급 · 락 / 칼립소",
            chords: [
                "C", "G", "Am", "F",
                "C", "G", "Am", "F",
                "C", "G", "Am", "F",
                "C", "G", "Am", "F",
                "C", "G", "Am", "F",
                "C", "G", "Am", "F",
                "C", "G", "Am", "F",
                "C", "G", "Am", "F",
            ],
            pick: .butterflyVerseRock,
            barPicks: [
                .butterflyVerseRock, .butterflyVerseRock, .butterflyVerseRock, .butterflyVerseRock,
                .butterflyVerseRock, .butterflyVerseRock, .butterflyVerseRock, .butterflyVerseRock,
                .butterflyVerseRock, .butterflyVerseRock, .butterflyVerseRock, .butterflyVerseRock,
                .butterflyVerseRock, .butterflyVerseRock, .butterflyVerseRock, .butterflyVerseRock,
                .butterflyChorusCalypso, .butterflyChorusCalypso, .butterflyChorusCalypso, .butterflyChorusCalypso,
                .butterflyChorusCalypso, .butterflyChorusCalypso, .butterflyChorusCalypso, .butterflyChorusCalypso,
                .butterflyChorusCalypso, .butterflyChorusCalypso, .butterflyChorusCalypso, .butterflyChorusCalypso,
                .butterflyChorusCalypso, .butterflyChorusCalypso, .butterflyChorusCalypso, .butterflyChorusCalypso,
            ],
            lyricBars: [
                "인트로", "", "", "", "", "", "", "",
                "1절 · 락", "", "", "", "", "", "", "",
                "프리 코러스", "", "", "", "", "", "", "",
                "후렴 · 칼립소", "", "", "", "", "", "", "",
            ]
        ),
        PracticeSong(
            title: "너에게 난 나에게 넌",
            level: "초급 · 16비트 포크 록",
            chords: [
                "G", "D", "Em", "Bm", "C", "G", "Am", "D7",
                "G", "D", "Em", "Bm", "C", "G", "Am", "D7",
                "G", "D", "Em", "Bm", "C", "G", "Am", "D7",
                "G", "D", "Em", "Bm", "C", "G", "Am", "D7",
            ],
            pick: .youAndIFullBar,
            lyricBars: [
                "인트로", "", "", "", "", "", "", "",
                "1절", "", "", "", "", "", "", "",
                "프리 코러스", "", "", "", "", "", "", "",
                "후렴", "", "", "", "", "", "", "",
            ]
        ),
    ]
}
