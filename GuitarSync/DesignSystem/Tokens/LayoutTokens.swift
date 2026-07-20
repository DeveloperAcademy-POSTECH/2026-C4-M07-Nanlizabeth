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
    /// iPhone 15/16 가로(852×393)를 기준으로 잡았다. 기존 `GuitarLayoutConstants`의
    /// 고정 수치(넥 760×310, 사운드홀 860×330)가 이 크기를 전제로 설계돼 있다.
    ///
    /// - Note: ⏳ Figma HI-FI 프레임 크기가 확인되면 그 값으로 교체할 것 (태스크 F2).
    ///   **이 상수 하나만 바꾸면 전 화면이 함께 따라간다.**
    static let referenceStage = CGSize(width: 852, height: 393)

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
