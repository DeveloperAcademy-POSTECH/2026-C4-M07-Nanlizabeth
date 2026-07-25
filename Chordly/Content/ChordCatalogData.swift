/// 코드 운지표 — **리서치 담당이 채우는 표.** (ROADMAP 태스크 CT3)
///
/// ## 채우는 법
///
/// 아래 목록에 한 줄씩 추가하면 끝이다. Swift를 몰라도 **패턴만 따라 쓰면** 된다.
///
/// ```swift
/// ChordEntry("F",  root: "F", frets: [1, 3, 3, 2, 1, 1]),
/// //          ↑이름       ↑근음        ↑6번줄부터 1번줄까지 6개
/// ```
///
/// ## 숫자 규약 (전 팀 공통 — ARCHITECTURE §5)
///
/// - **줄 순서**: 왼쪽부터 `6번줄(가장 굵은 저음 E)` → `1번줄(가장 얇은 고음 E)`.
///   즉 `frets[0]`이 6번줄이다. 기타 코드표를 볼 때 흔히 그리는 순서와 같다.
/// - **숫자 뜻**: `-1` = 뮤트(X, 치지 않음) · `0` = 개방현(안 짚고 침) · `1~` = 프렛 번호
/// - **개수**: 반드시 **6개**.
///
/// ## 확인하는 법
///
/// 여기에 추가한 코드는 `ChordCatalog.shared.allChords`에 자동으로 들어가고,
/// 코드 선택 화면·커스텀 진행 화면에 **바로 나타난다.** 별도 등록 작업 없음.
enum ChordCatalogData {
    static let entries: [ChordEntry] = [
        // ── 기본 오픈 코드 (프로토타입부터 있던 7개) ──────────────────────
        //             이름        근음        6→1번줄 운지            6→1번줄 손가락(0안짚음 1검지 2중지 3약지 4새끼)
        ChordEntry("C",  root: "C", frets: [-1,  3,  2,  0,  1,  0], fingers: [0, 3, 2, 0, 1, 0]),
        ChordEntry("C7", root: "C", frets: [-1,  3,  2,  3,  1,  0], fingers: [0, 3, 2, 4, 1, 0]),
        ChordEntry("D",  root: "D", frets: [-1, -1,  0,  2,  3,  2], fingers: [0, 0, 0, 1, 3, 2]),
        ChordEntry("Dm", root: "D", frets: [-1, -1,  0,  2,  3,  1], fingers: [0, 0, 0, 2, 3, 1]),
        ChordEntry("Dm7", root: "D", frets: [-1, -1,  0,  2,  1,  1], fingers: [0, 0, 0, 2, 1, 1]),
        ChordEntry("E",  root: "E", frets: [ 0,  2,  2,  1,  0,  0], fingers: [0, 2, 3, 1, 0, 0]),
        ChordEntry("E7", root: "E", frets: [ 0,  2,  0,  1,  0,  0], fingers: [0, 2, 0, 1, 0, 0]),
        ChordEntry("G",  root: "G", frets: [ 3,  2,  0,  0,  0,  3], fingers: [2, 1, 0, 0, 0, 3]),
        ChordEntry("G7", root: "G", frets: [ 3,  2,  0,  0,  0,  1], fingers: [3, 2, 0, 0, 0, 1]),
        ChordEntry("A",  root: "A", frets: [-1,  0,  2,  2,  2,  0], fingers: [0, 0, 1, 2, 3, 0]),
        ChordEntry("Aadd9", root: "A", frets: [-1,  0,  2,  2,  0,  0], fingers: [0, 0, 1, 2, 0, 0]),
        ChordEntry("Am", root: "A", frets: [-1,  0,  2,  2,  1,  0], fingers: [0, 0, 2, 3, 1, 0]),
        ChordEntry("Bm", root: "B", frets: [-1,  2,  4,  4,  3,  2], fingers: [0, 1, 3, 4, 2, 1]),
        ChordEntry("D7", root: "D", frets: [-1, -1,  0,  2,  1,  2], fingers: [0, 0, 0, 2, 1, 3]),
        ChordEntry("Dadd9", root: "D", frets: [-1, -1,  0,  2,  3,  0], fingers: [0, 0, 0, 1, 3, 0]),
        ChordEntry("Em", root: "E", frets: [ 0,  2,  2,  0,  0,  0], fingers: [0, 2, 3, 0, 0, 0]),
        ChordEntry("Bsus4", root: "B", frets: [-1,  2,  4,  4,  5,  2], fingers: [0, 1, 3, 3, 4, 1]),
        ChordEntry("C#m7", root: "C#", frets: [-1,  4,  6,  4,  5,  4], fingers: [0, 1, 3, 1, 2, 1]),
        ChordEntry("F#sus4", root: "F#", frets: [ 2,  4,  4,  4,  2,  2], fingers: [1, 3, 3, 4, 1, 1]),
        ChordEntry("F#7sus4", root: "F#", frets: [ 2,  4,  2,  4,  2,  2], fingers: [1, 3, 1, 4, 1, 1]),

        // ── 머니코드(C→G→Am→F)를 완성하는 데 필요한 코드 ──────────────────
        // F: 검지(1)가 1프렛에서 6·2·1번줄을 바레. 6번줄과 2·1번줄은 떨어져 있어(2·3번줄은
        // 약지·새끼가 위에서 누름) 화면엔 원으로 나뉘어 보인다.
        ChordEntry("F",  root: "F", frets: [ 1,  3,  3,  2,  1,  1], fingers: [1, 3, 4, 2, 1, 1]),
        ChordEntry("Fmaj7", root: "F", frets: [-1, -1,  3,  2,  1,  0], fingers: [0, 0, 3, 2, 1, 0]),

        // ── 👇 CT3 리서치 결과를 여기에 이어서 추가하세요 ────────────────────
        // 프리셋 진행(캐논 등)에 필요한 코드를 조사해 채웁니다.
        // 예상 후보: Dm, Bm, C7, G7, Cmaj7, Dm7, B7, Fmaj7 …
    ]
}
