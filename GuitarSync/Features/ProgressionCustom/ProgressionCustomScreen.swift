import SwiftUI

/// 화면 7 — 코드진행 커스텀. (SPEC 플로우 2 / ARCHITECTURE §3.6 · ROADMAP 태스크 U6)
///
/// ## 만들 때 챙길 것
/// - 코드는 **반드시 `ChordCatalog.shared`에서** 고른다. 화면 전용 코드 목록을 만들지 않는다
///   (그래야 "커스텀에서 프리셋 코드 재사용"이 저절로 된다).
/// - 코드/진행을 탭하면 **미리듣기**. 항상 하나만 재생 — 새 미리듣기가 이전 것을 자동 정지
///   (`ProgressionPreviewPlayerProtocol`).
/// - 미리듣기 진짜 구현은 L4가 완성한다. 그전에는 `MockProgressionPreviewPlayer`로 개발 가능.
/// - 결정 버튼 → `library.saveCustom(_:)` (JSON 저장은 이미 동작한다).
struct ProgressionCustomScreen: View {
    var body: some View {
        ScreenPlaceholder(
            route: .progressionCustom,
            task: "U6",
            hint: "카탈로그에서 코드 배치 + 미리듣기 + 결정"
        )
    }
}
