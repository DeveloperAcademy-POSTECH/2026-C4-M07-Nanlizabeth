import SwiftUI

/// 앱이 쓰는 **모든 색.** (ARCHITECTURE §5 규약: 색을 화면에서 직접 만들지 않는다)
///
/// ## ⏳ 지금 값은 임시입니다 (태스크 F2 진행 중)
///
/// 아래 값은 **기존 프로토타입 코드에 흩어져 있던 색을 모아 이름만 붙인 것**입니다.
/// Figma HI-FI의 '디자인 스타일'을 확보하면 **이 파일의 숫자만** 바꿉니다 —
/// 화면 코드는 이름으로 참조하므로 한 줄도 안 고쳐도 됩니다. 그게 토큰을 쓰는 이유입니다.
///
/// ## 쓰는 법
///
/// ```swift
/// Color.gsStageBackground          // ✅
/// Color(red: 0.02, green: 0.04, blue: 0.045)   // ❌ 숫자 직접 쓰기 금지
/// ```
enum ColorTokens {

    // MARK: - 배경

    /// 앱 전체 바탕. 거의 검정에 가까운 청록빛 어둠.
    static let stageBackground = Color(red: 0.02, green: 0.04, blue: 0.045)
    /// 연주 화면(스트럼)의 바탕 — 스테이지보다 아주 약간 밝다.
    static let performanceBackground = Color(red: 0.03, green: 0.04, blue: 0.045)
    /// 카드·팝오버 등 떠 있는 면.
    static let surface = Color(red: 0.08, green: 0.09, blue: 0.10)
    /// 팝오버 위의 강조 면 (BPM 슬라이더 트랙 등).
    static let surfaceRaised = Color(red: 0.30, green: 0.34, blue: 0.42)

    // MARK: - 기타넥 (운지 화면)

    /// 지판(프렛보드) 나무면.
    static let neckSurface = Color(red: 0.08, green: 0.10, blue: 0.12)
    /// 프렛 쇠줄.
    static let fretWire = Color(red: 0.72, green: 0.78, blue: 0.85)
    /// 줄 — 밝게 빛나는 상태.
    static let stringBright = Color(red: 0.88, green: 0.92, blue: 0.97)
    /// 줄 — 가라앉은 상태.
    static let stringDim = Color(red: 0.46, green: 0.53, blue: 0.62)

    // MARK: - 스트럼 (긁는 화면)

    /// 울림통 나무 — 밝은 쪽.
    static let bodyWoodLight = Color(red: 0.42, green: 0.20, blue: 0.075)
    /// 울림통 나무 — 중간.
    static let bodyWoodMid = Color(red: 0.12, green: 0.065, blue: 0.030)
    /// 울림통 나무 — 어두운 쪽.
    static let bodyWoodDark = Color(red: 0.10, green: 0.055, blue: 0.025)
    /// 스트럼 화면의 줄.
    static let strumString = Color(red: 0.72, green: 0.78, blue: 0.84)
    /// 줄 이미지 위에 얹는 색조.
    static let strumStringTint = Color(red: 0.62, green: 0.69, blue: 0.72)

    // MARK: - 글자

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.4)
    /// 밝은 배경 위 글자 (흰 버튼 안 등).
    static let textOnLight = Color.black
}

extension Color {
    static let gsStageBackground = ColorTokens.stageBackground
    static let gsPerformanceBackground = ColorTokens.performanceBackground
    static let gsSurface = ColorTokens.surface
    static let gsSurfaceRaised = ColorTokens.surfaceRaised

    static let gsNeckSurface = ColorTokens.neckSurface
    static let gsFretWire = ColorTokens.fretWire
    static let gsStringBright = ColorTokens.stringBright
    static let gsStringDim = ColorTokens.stringDim

    static let gsBodyWoodLight = ColorTokens.bodyWoodLight
    static let gsBodyWoodMid = ColorTokens.bodyWoodMid
    static let gsBodyWoodDark = ColorTokens.bodyWoodDark
    static let gsStrumString = ColorTokens.strumString
    static let gsStrumStringTint = ColorTokens.strumStringTint

    static let gsTextPrimary = ColorTokens.textPrimary
    static let gsTextSecondary = ColorTokens.textSecondary
    static let gsTextTertiary = ColorTokens.textTertiary
    static let gsTextOnLight = ColorTokens.textOnLight
}
