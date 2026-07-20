/// 코드진행 프리셋 — **리서치 담당이 채우는 표.** (ROADMAP 태스크 CT2)
///
/// ## 채우는 법
///
/// 진행 하나 = 코드가 바뀌는 순서 + 각 코드를 몇 마디 유지하는가.
///
/// ```swift
/// ChordProgression(
///     name: "머니코드",
///     items: [ProgressionItem("C"), ProgressionItem("G"),
///             ProgressionItem("Am"), ProgressionItem("F")],
///     recommendedBPM: 80
/// )
/// ```
///
/// - `ProgressionItem("C")` → C코드를 **1마디**
/// - `ProgressionItem("C", bars: 2)` → C코드를 **2마디**
///
/// ## ⚠️ 먼저 확인할 것
///
/// 여기 쓰는 코드 이름은 **`ChordCatalogData`에 운지가 등록돼 있어야** 소리가 난다.
/// 없는 코드를 쓰면 개방현 소리가 나므로, 새 코드를 쓸 땐 `ChordCatalogData`부터 채운다.
/// (그래서 ROADMAP에서 CT2의 선행 작업이 CT3다)
///
/// ## 확인하는 법
///
/// 여기에 추가하면 코드진행 선택 화면에 **바로 나타난다.**
enum ProgressionPresetData {
    static let progressions: [ChordProgression] = [
        // ── 머니코드 — 대중가요에서 가장 많이 쓰이는 4코드 ───────────────────
        ChordProgression(
            name: "머니코드",
            items: [
                ProgressionItem("C"),
                ProgressionItem("G"),
                ProgressionItem("Am"),
                ProgressionItem("F"),
            ],
            recommendedBPM: 80
        ),

        // ── 기본 3코드 — 가장 먼저 배우는 진행 ──────────────────────────────
        ChordProgression(
            name: "기본 3코드",
            items: [
                ProgressionItem("C", bars: 2),
                ProgressionItem("F"),
                ProgressionItem("G"),
            ],
            recommendedBPM: 90
        ),

        // ── 👇 CT2 리서치 결과를 여기에 이어서 추가하세요 ────────────────────
        // 예상 후보: 캐논 진행 · 반복되는 4코드 변형 · 마이너 진행 …
        //
        // 캐논은 Em·Bm·D 등이 필요하므로 ChordCatalogData에 먼저 추가해야 합니다.
    ]
}
