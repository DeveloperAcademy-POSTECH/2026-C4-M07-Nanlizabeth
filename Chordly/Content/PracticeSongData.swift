/// 코드 드릴 연습곡 목록 — **저작권 걱정 없는 곡만.** (docs/PLAN-chord-drill 확장)
///
/// ## 고른 기준
///
/// 전부 **퍼블릭 도메인**(전래동요·전통 찬송가·트래디셔널 포크)이라 멜로디 저작권이 소멸했거나
/// 애초에 없다. 코드 진행 자체는 저작권 대상이 아니다. 교본에 자주 나오는 쉬운 곡부터 담았다.
///
/// - 떴다 떴다 비행기 · 산토끼 · 학교종 · 반짝반짝 작은 별(모차르트 선율) — 전래/고전 동요
/// - Amazing Grace(1779 찬송가) · House of the Rising Sun(전통 포크) — 교본 단골 기타곡
///
/// ## 채우는 법
///
/// 아래에 한 줄 추가하면 노래 선택 화면과 드릴에 바로 나타난다. **코드는 `ChordCatalog`에 있는
/// 것만** 쓴다 (현재: C·D·E·G·A·Am·Em·F). 연속으로 같은 코드가 겹치지 않게 적는다(넘어감 처리됨).
enum PracticeSongData {
    static let songs: [PracticeSong] = [
        // ── 입문 : 코드 2개 ─────────────────────────────────────────
        PracticeSong(title: "떴다 떴다 비행기", level: "입문", chords: ["C", "G"], pick: .bassStrum),

        // ── 초급 : 코드 3개 ─────────────────────────────────────────
        PracticeSong(title: "반짝반짝 작은 별", level: "초급", chords: ["C", "F", "G"],      pick: .arpeggioUp),
        PracticeSong(title: "학교종",          level: "초급", chords: ["C", "F", "C", "G"], pick: .bassStrum),
        PracticeSong(title: "산토끼",          level: "초급", chords: ["G", "C", "D"],      pick: .bassStrum),

        // ── 중급 : 교본 단골 기타곡 ──────────────────────────────────
        PracticeSong(title: "Amazing Grace",           level: "중급", chords: ["G", "C", "G", "D"],           pick: .waltz),
        PracticeSong(title: "House of the Rising Sun", level: "중급", chords: ["Am", "C", "D", "F", "Am", "E"], pick: .arpeggioUp),
    ]
}
