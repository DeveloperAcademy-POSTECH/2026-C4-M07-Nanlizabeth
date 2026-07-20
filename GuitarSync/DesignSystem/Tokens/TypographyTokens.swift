import SwiftUI

/// 글자 스타일. (ARCHITECTURE §5 규약: 크기를 화면에서 직접 쓰지 않는다)
///
/// ## ⏳ 지금 값은 임시입니다 (태스크 F2 진행 중)
/// 기존 코드에서 실제로 쓰이던 크기들을 역할별로 묶은 것입니다.
/// Figma의 텍스트 스타일을 확보하면 이 파일만 교체합니다.
///
/// ```swift
/// Text("스트로크 선택").font(.gsTitle)     // ✅
/// Text("스트로크 선택").font(.system(size: 28, weight: .bold))   // ❌
/// ```
///
/// - Note: ⚠️ **다이내믹 타입(글자 크기 설정) 대응은 아직 없다.** 고정 크기라
///   사용자가 글자를 키워도 반응하지 않는다. 대응은 태스크 H4에서 —
///   그때 `.system(size:)` 대신 `.custom(_:size:relativeTo:)`로 바꾸면 이 파일만 고치면 된다.
enum Typography {
    /// 72 — 연주 중 코드 이름처럼 화면을 지배하는 글자
    static let display = Font.system(size: 72, weight: .bold)
    /// 28 — 화면 제목
    static let title = Font.system(size: 28, weight: .bold)
    /// 22 — 구역 제목
    static let heading = Font.system(size: 22, weight: .semibold)
    /// 18 — 강조된 본문
    static let bodyLarge = Font.system(size: 18, weight: .medium)
    /// 15 — 기본 본문. 헷갈리면 이걸 쓴다
    static let body = Font.system(size: 15, weight: .regular)
    /// 15 — 버튼 글자
    static let button = Font.system(size: 15, weight: .semibold)
    /// 13 — 보조 설명
    static let caption = Font.system(size: 13, weight: .regular)
    /// 11 — 라벨·단위
    static let label = Font.system(size: 11, weight: .medium)
}

extension Font {
    static let gsDisplay = Typography.display
    static let gsTitle = Typography.title
    static let gsHeading = Typography.heading
    static let gsBodyLarge = Typography.bodyLarge
    static let gsBody = Typography.body
    static let gsButton = Typography.button
    static let gsCaption = Typography.caption
    static let gsLabel = Typography.label
}
