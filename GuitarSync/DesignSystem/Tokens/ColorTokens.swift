import SwiftUI

/// 앱이 쓰는 **모든 색.** (ARCHITECTURE §5 규약: 색을 화면에서 직접 만들지 않는다)
///
/// ## 출처 (2026-07-20, 태스크 F2)
///
/// Figma `C4-난리자베스` → `Hi-Fi` 섹션에서 추출했습니다.
/// - **면 색**은 HI-FI 화면(`코드 모드 - 기본`, `스트로크 선택 페이지`)을 렌더해 픽셀에서 직접 뽑음
/// - **글자·구분선 색**은 Figma 변수(Apple `Labels - Vibrant` 계열)에서 가져옴
///
/// 디자인이 Apple 기본 디자인 시스템(SF Pro + Liquid Glass) 위에 얹혀 있어서,
/// 커스텀 값은 **면 색 4개와 액센트 1개**뿐입니다.
///
/// ## 쓰는 법
///
/// ```swift
/// Color.gsAccent                               // ✅
/// Color(red: 0.91, green: 1.0, blue: 0.07)     // ❌ 숫자 직접 쓰기 금지
/// ```
enum ColorTokens {

    // MARK: - 액센트 ★이 앱의 시그니처

    /// 형광 라임. **선택됨·활성 상태를 나타내는 유일한 강조색.**
    ///
    /// 스트로크/코드 선택 화면에서 고른 항목, 재생 중 표시 등에 쓴다.
    /// 배경이 거의 검정이라 이 색 하나만으로 시선이 잡힌다 — 남발하면 효과가 죽는다.
    static let accent = Color(hex: 0xE7FF12)
    /// 액센트 위에 얹는 글자색. 라임이 매우 밝아서 **반드시 검정**이다.
    static let onAccent = Color(hex: 0x000000)

    // MARK: - 배경·면

    /// 앱 전체 바탕. 가장 어두운 면.
    static let stageBackground = Color(hex: 0x0B0E11)
    /// 기타넥 지판면. 바탕보다 살짝 밝은 청회색.
    static let neckSurface = Color(hex: 0x161A20)
    /// 목록 행·카드처럼 떠 있는 면.
    static let surface = Color(hex: 0x343639)
    /// 줄·프렛 등 중간 밝기 요소.
    static let hardware = Color(hex: 0x52525C)
    /// 구분선.
    static let separator = Color(hex: 0x1A1A1A)

    // MARK: - 글자
    //
    // Apple의 Vibrant 라벨 계열을 따른다 — 어두운 배경에서 순백(#fff)은 눈이 부시므로
    // Primary도 #f5f5f5를 쓴다.

    static let textPrimary = Color(hex: 0xF5F5F5)
    static let textSecondary = Color(hex: 0xF5F5F5).opacity(0.6)
    static let textTertiary = Color(hex: 0x404040)
    /// 밝은 배경(라임·흰 버튼) 위 글자.
    static let textOnLight = Color(hex: 0x000000)
}

extension Color {
    /// `0xRRGGBB` 형태로 색을 만든다. **토큰 파일 안에서만** 쓴다.
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let gsAccent = ColorTokens.accent
    static let gsOnAccent = ColorTokens.onAccent

    static let gsStageBackground = ColorTokens.stageBackground
    static let gsNeckSurface = ColorTokens.neckSurface
    static let gsSurface = ColorTokens.surface
    static let gsHardware = ColorTokens.hardware
    static let gsSeparator = ColorTokens.separator

    static let gsTextPrimary = ColorTokens.textPrimary
    static let gsTextSecondary = ColorTokens.textSecondary
    static let gsTextTertiary = ColorTokens.textTertiary
    static let gsTextOnLight = ColorTokens.textOnLight
}
