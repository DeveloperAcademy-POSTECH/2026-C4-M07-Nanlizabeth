import SwiftUI

/// 레이아웃 규약 (ARCHITECTURE §2.5 / ROADMAP F1 결정문).
///
/// **결정 요약**
/// 1. 앱은 `Info.plist`상 **세로 고정**이고, `PortraitLockedLandscapeStage`가 콘텐츠를
///    -90° 회전시켜 가로 화면을 만든다. (기존 방식 공식화)
/// 2. 기준 도화지가 **기기별로 둘**이다 — iPhone 874×402, iPad 1366×1024.
///    같은 기기 안에서는 **통째로 비율 스케일**해 맞추므로, 화면 담당은 해상도를 신경 쓸 필요가 없다.
///
/// ## 화면 담당이 알아야 할 것
///
/// - **iPhone 전용 화면**(기타넥·스트로크 선택)은 874×402 도화지에만 그리면 된다.
/// - **양쪽에 다 나오는 화면**(스트럼·진행 선택·연결·온보딩)은 두 비율 모두에서 말이 되게 짜야 한다.
///   `@Environment(\.stageMetrics)`로 지금 어느 도화지인지 알 수 있다.
/// - ⚠️ **iPhone 레이아웃을 그대로 늘리지 말 것.** 2.17 : 1.33은 너무 달라서 늘리면 어색해진다.
///   Figma도 iPad 스트럼 화면을 따로 그렸다 (사운드홀을 중앙에 크게, 줄이 화면 전체를 관통).
enum LayoutTokens {
    /// iPhone 기준 도화지 (가로). **Figma HI-FI의 iPhone 프레임과 동일** (874×402).
    ///
    /// iPhone 16 Pro / 17 가로 해상도이기도 해서 해당 기기에서는 배율이 정확히 1.0이 된다.
    static let phoneStage = CGSize(width: 874, height: 402)

    /// iPad 기준 도화지 (가로). **Figma HI-FI의 iPad Pro 12.9" 프레임과 동일** (1366×1024).
    static let padStage = CGSize(width: 1366, height: 1024)

    /// 이 기기가 쓰는 기준 도화지.
    ///
    /// 두 기준을 나눈 이유: 가로세로비가 **iPhone 2.17 : iPad 1.33**으로 크게 다르다.
    /// 하나를 스케일해서 쓰면 iPad에서 위아래가 크게 비거나 잘린다 —
    /// 그래서 Figma도 iPad 화면을 따로 그렸다 (ARCHITECTURE §2.5).
    static func referenceStage(for deviceType: DeviceType = DeviceInfoProvider.currentDeviceType) -> CGSize {
        deviceType == .iPad ? padStage : phoneStage
    }

    /// 기본 기준 도화지 (현재 기기 기준).
    ///
    /// - Note: 화면 코드가 크기를 직접 읽어야 할 때만 쓴다. 보통은 스테이지가 알아서 처리한다.
    static var referenceStage: CGSize { referenceStage() }

    /// 기준 도화지를 실제 스테이지 크기에 맞추기 위한 배율.
    ///
    /// 잘림 방지를 위해 가로·세로 배율 중 **작은 쪽**을 쓴다(fit). 남는 여백은 배경색으로 채워진다.
    static func scale(reference: CGSize, in stageSize: CGSize) -> CGFloat {
        guard reference.width > 0, reference.height > 0 else { return 1 }
        return min(stageSize.width / reference.width, stageSize.height / reference.height)
    }
}

/// 지금 그리고 있는 도화지의 정보.
///
/// 양쪽 기기에 다 나오는 화면이 **기기를 직접 묻지 않고** 레이아웃을 바꿀 수 있게 해준다.
///
/// ```swift
/// @Environment(\.stageMetrics) private var stage
///
/// if stage.isWide {           // iPad — 사운드홀을 중앙에 크게
///     WideStrumLayout()
/// } else {                    // iPhone — 가로로 긴 배치
///     CompactStrumLayout()
/// }
/// ```
struct StageMetrics: Equatable {
    /// 이 화면이 그려지는 기준 도화지 크기.
    var reference: CGSize
    /// 기준 도화지 → 실제 화면 배율.
    ///
    /// **햅틱·제스처 임계값처럼 "실제 물리 거리"가 필요한 계산에만** 곱해서 쓴다.
    var scale: CGFloat

    /// iPad처럼 **세로가 넉넉한** 도화지인가 (가로세로비 1.7 미만).
    ///
    /// 기기 종류가 아니라 **비율**로 판단한다 — 새 기기가 나와도 코드를 안 고쳐도 된다.
    var isWide: Bool { reference.width / reference.height < 1.7 }

    static let phone = StageMetrics(reference: LayoutTokens.phoneStage, scale: 1)
}

private struct StageMetricsKey: EnvironmentKey {
    static let defaultValue = StageMetrics.phone
}

extension EnvironmentValues {
    var stageMetrics: StageMetrics {
        get { self[StageMetricsKey.self] }
        set { self[StageMetricsKey.self] = newValue }
    }

    /// 기준 도화지 → 실제 화면 배율. `stageMetrics.scale`의 지름길.
    var stageScale: CGFloat { stageMetrics.scale }
}
