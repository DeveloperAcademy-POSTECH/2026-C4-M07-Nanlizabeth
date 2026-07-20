import SwiftUI

/// 글자 스타일. (ARCHITECTURE §5 규약: 크기를 화면에서 직접 쓰지 않는다)
///
/// ## 출처 (2026-07-20, 태스크 F2)
///
/// Figma가 **Apple 기본 텍스트 스타일(SF Pro)을 그대로** 쓰고 있어서, 커스텀 스케일을 만들지 않고
/// iOS 표준 스타일에 1:1로 맞췄습니다. Figma 변수에서 확인된 값:
///
/// | 이름 | 크기 | 굵기 | 행간 |
/// |------|------|------|------|
/// | Title1 | 28 | regular | 34 |
/// | Title2 | 22 | regular | 28 |
/// | Headline | 17 | semibold | 22 |
/// | Body | 17 | regular | 22 |
/// | Subheadline | 15 | regular | 20 |
/// | Footnote | 13 | regular | 18 |
///
/// ## 왜 `.system(size:)`가 아니라 `Font.TextStyle`을 쓰나
///
/// Apple 표준 스타일에 맞췄으므로 **`.title`·`.body` 같은 시맨틱 스타일을 쓸 수 있고,
/// 그러면 다이내믹 타입(사용자 글자 크기 설정)이 공짜로 따라온다.** 접근성(H4)에서 따로 손댈 게 없어진다.
///
/// ```swift
/// Text("코드 모드").font(.gsTitle)                  // ✅ 글자 크기 설정에 반응함
/// Text("코드 모드").font(.system(size: 28))         // ❌ 고정 크기, 접근성 대응 안 됨
/// ```
///
/// - Note: ⚠️ 연주 화면처럼 **레이아웃이 깨지면 안 되는 곳**은 다이내믹 타입이 위험할 수 있다.
///   그런 자리는 `.gsFixed(...)`를 쓰고, 왜 고정인지 주석을 남길 것.
enum Typography {
    /// 28 — 화면 제목 (Apple Title1)
    static let title = Font.system(.title, design: .default)
    /// 22 — 구역 제목 (Apple Title2)
    static let heading = Font.system(.title2, design: .default)
    /// 17 semibold — 강조된 본문·버튼 (Apple Headline)
    static let headline = Font.system(.headline, design: .default)
    /// 17 — 기본 본문. 헷갈리면 이걸 쓴다 (Apple Body)
    static let body = Font.system(.body, design: .default)
    /// 15 — 보조 본문 (Apple Subheadline)
    static let subheadline = Font.system(.subheadline, design: .default)
    /// 13 — 캡션·라벨 (Apple Footnote)
    static let caption = Font.system(.footnote, design: .default)

    /// 다이내믹 타입을 **의도적으로 끈** 고정 크기.
    ///
    /// 코드 이름처럼 크기가 곧 디자인인 자리에만 쓴다. 쓸 때는 이유를 주석으로 남긴다.
    static func fixed(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension Font {
    static let gsTitle = Typography.title
    static let gsHeading = Typography.heading
    static let gsHeadline = Typography.headline
    static let gsBody = Typography.body
    static let gsSubheadline = Typography.subheadline
    static let gsCaption = Typography.caption

    /// 다이내믹 타입을 끈 고정 크기 — 이유가 있을 때만.
    static func gsFixed(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Typography.fixed(size, weight: weight)
    }
}
