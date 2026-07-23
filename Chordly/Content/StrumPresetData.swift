/// 주법(스트로크 리듬) 프리셋 — **리서치 담당이 채우는 표.** (ROADMAP 태스크 CT1)
///
/// ## 채우는 법
///
/// 리듬 하나 = `StrumPattern` 하나. 그 안에 "언제 어느 방향으로 긁나"를 `StrumStep`으로 나열한다.
///
/// ```swift
/// StrumStep(beat: 1, sub: 2, .down, .medium)
/// //          ↑2박째   ↑뒤쪽 8분음표  ↑아래로  ↑중간 세기
/// ```
///
/// ## 숫자 읽는 법
///
/// - **`beat`**: 몇 박째인가. **0부터** 센다 → `0`=1박, `1`=2박, `2`=3박, `3`=4박
/// - **`sub`**: 그 박을 4등분(16분음표)한 위치. **0부터** 센다
///   - `0` = 정박 ("하나")
///   - `2` = 박의 한가운데, 8분음표 뒤 ("하나 **그**")
///   - `1`, `3` = 16분음표 자리 (빠른 리듬에만)
/// - **방향**: `.down` = 저음줄→고음줄 (아래로 훑기) · `.up` = 반대
/// - **세기**: `.strong` / `.medium` / `.soft`
///
/// ## 예시로 이해하기 — 칼립소
///
/// 흔히 "쿵 짝 쿵쿵 짝"으로 부르는 리듬을 표로 옮기면:
///
/// | 언제 | 방향 | 세기 | 코드 |
/// |------|------|------|------|
/// | 1박 정박 | ↓ | 강 | `StrumStep(beat: 0, sub: 0, .down, .strong)` |
/// | 2박 뒤 | ↓ | 중 | `StrumStep(beat: 1, sub: 2, .down, .medium)` |
/// | 3박 정박 | ↑ | 약 | `StrumStep(beat: 2, sub: 0, .up, .soft)` |
///
/// ## 확인하는 법
///
/// 여기에 추가하면 스트로크 선택 화면에 **바로 나타난다.** 별도 등록 작업 없음.
enum StrumPresetData {
    static let patterns: [StrumPattern] = [
        // ── 가장 기본: 4비트 다운 스트로크 ────────────────────────────────
        // 매 박마다 아래로 한 번. 첫 박만 세게.
        StrumPattern(
            name: "4비트 기본",
            steps: (0..<4).map { beat in
                StrumStep(beat: beat, sub: 0, .down, beat == 0 ? .strong : .medium)
            },
            recommendedBPM: 80
        ),

        // ── 8비트: 다운-업을 번갈아 ──────────────────────────────────────
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

        // ── 👇 CT1 리서치 결과를 여기에 이어서 추가하세요 ────────────────────
        // 초보자용 스트로크 리듬을 조사해 위 형식으로 채웁니다.
        // 예상 후보: 칼립소 · 고고 · 슬로우 고고 · 셔플 · 발라드 …
        //
        // 위 MockStrumPatternLibrary.stubPresets에 칼립소 예시가 하나 들어 있으니
        // 형태가 헷갈리면 그걸 참고하세요.
    ]
}
