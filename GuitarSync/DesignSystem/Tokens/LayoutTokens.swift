import SwiftUI

/// 레이아웃 규약 (ARCHITECTURE §2.5 / ROADMAP F1 결정문).
///
/// **결정 요약**
/// 1. 앱은 `Info.plist`상 **세로 고정**이고, `PortraitLockedLandscapeStage`가 콘텐츠를
///    -90° 회전시켜 가로 화면을 만든다. (기존 방식 공식화)
/// 2. 모든 화면은 아래 `referenceStage` **기준 해상도로 그린다.** 실제 기기 크기에는
///    스테이지가 **통째로 비율 스케일**해서 맞춘다. → 화면 담당은 기기 대응을 신경 쓸 필요가 없다.
///
/// 즉 화면을 만들 때는 "지금 기기가 뭐지?"를 묻지 말고 **852×393 도화지에 그린다고 생각하면 된다.**
enum LayoutTokens {
    /// 모든 화면이 그려지는 기준 도화지 크기 (가로 기준).
    ///
    /// **Figma HI-FI의 iPhone 프레임 크기와 동일하다** (2026-07-20 확인, 태스크 F2).
    /// iPhone 16 Pro / 17 가로 해상도이기도 해서, 해당 기기에서는 배율이 정확히 1.0이 된다.
    ///
    /// - Note: **이 상수 하나만 바꾸면 전 화면이 함께 따라간다.**
    /// - Important: ⚠️ Figma에는 **iPad Pro 12.9" 전용 프레임(1366×1024)이 따로 있다.**
    ///   가로세로비가 iPhone 2.17 : iPad 1.33으로 크게 달라, 이 값 하나를 스케일하는 방식으로는
    ///   iPad에서 위아래 여백이 크게 남는다. iPad 대응 방침은 **미결정** — ARCHITECTURE §2.5 참고.
    static let referenceStage = CGSize(width: 874, height: 402)

    /// Figma에 있는 iPad Pro 12.9" 프레임 크기. **아직 코드에서 쓰지 않는다** (대응 방침 미결정).
    static let iPadReferenceStage = CGSize(width: 1366, height: 1024)

    /// 기준 도화지를 실제 스테이지 크기에 맞추기 위한 배율.
    ///
    /// 잘림 방지를 위해 가로·세로 배율 중 **작은 쪽**을 쓴다(fit). 남는 여백은 배경색으로 채워진다.
    static func scale(for stageSize: CGSize) -> CGFloat {
        guard referenceStage.width > 0, referenceStage.height > 0 else { return 1 }
        let widthScale = stageSize.width / referenceStage.width
        let heightScale = stageSize.height / referenceStage.height
        return min(widthScale, heightScale)
    }
}

private struct StageScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    /// 기준 도화지 → 실제 화면 배율.
    ///
    /// 화면 코드는 보통 이걸 쓸 일이 없다(스테이지가 알아서 스케일한다).
    /// **햅틱·제스처 임계값처럼 "실제 물리 거리"가 필요한 계산에만** 곱해서 쓴다.
    var stageScale: CGFloat {
        get { self[StageScaleKey.self] }
        set { self[StageScaleKey.self] = newValue }
    }
}
