import SwiftUI

/// 여백·모서리 둥글기. (ARCHITECTURE §5 규약: 숫자를 화면에서 직접 쓰지 않는다)
///
/// ## ⏳ 지금 값은 임시입니다 (태스크 F2 진행 중)
/// 기존 코드에서 실제로 쓰이던 값들을 4의 배수 눈금으로 정리한 것입니다.
/// Figma 확보 후 이 파일의 숫자만 교체합니다.
///
/// ```swift
/// .padding(Spacing.md)      // ✅
/// .padding(16)              // ❌
/// ```
enum Spacing {
    /// 4 — 아이콘과 글자 사이처럼 아주 좁은 틈
    static let xxs: CGFloat = 4
    /// 8 — 관련 있는 요소끼리
    static let xs: CGFloat = 8
    /// 12 — 목록 항목 안쪽
    static let sm: CGFloat = 12
    /// 16 — 기본 여백. 헷갈리면 이걸 쓴다
    static let md: CGFloat = 16
    /// 20 — 카드 안쪽
    static let lg: CGFloat = 20
    /// 32 — 구역과 구역 사이
    static let xl: CGFloat = 32
    /// 44 — 화면 가장자리 (컨트롤 바가 있는 쪽)
    static let xxl: CGFloat = 44
}

/// 모서리 둥글기.
enum Radius {
    /// 8 — 작은 칩·태그
    static let sm: CGFloat = 8
    /// 10 — 버튼
    static let md: CGFloat = 10
    /// 18 — 카드·팝오버
    static let lg: CGFloat = 18
    /// 완전한 알약 모양
    static let pill: CGFloat = 999
}

/// 터치 목표 최소 크기.
///
/// - Note: 접근성 기준(44pt)이다. 기타넥의 프렛 칸처럼 **악기 특성상 더 작아지는 곳**은
///   예외로 두되, 버튼류는 반드시 지킨다 (태스크 H4).
enum HitTarget {
    static let minimum: CGFloat = 44
}
