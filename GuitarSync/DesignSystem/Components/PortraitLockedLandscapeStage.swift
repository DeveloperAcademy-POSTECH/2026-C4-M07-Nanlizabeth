import SwiftUI

private struct LandscapeStageSafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue = EdgeInsets()
}

extension EnvironmentValues {
    var landscapeStageSafeAreaInsets: EdgeInsets {
        get { self[LandscapeStageSafeAreaInsetsKey.self] }
        set { self[LandscapeStageSafeAreaInsetsKey.self] = newValue }
    }
}

/// 콘텐츠를 가로 도화지 하나에 그리게 해주는 스테이지 (ARCHITECTURE §2.5 / 태스크 F1).
///
/// **기기에 따라 가로를 만드는 방식이 다르다:**
/// - 📱 **iPhone** — 앱이 세로 고정이라(Info.plist), 콘텐츠를 **-90° 돌려** 가로로 세운다.
/// - 📲 **iPad** — 기기 자체가 가로로 뜨므로(Info.plist `~ipad` = Landscape) **회전하지 않고**
///   그대로 그린다. (iPad를 90° 돌려 쓰는 문제를 없앤 것 — 2026-07-21)
///
/// 어느 쪽이든 콘텐츠는 **하나의 가로 도화지**(`reference`, 기본 874×402)만 생각하면 된다.
/// 실제 기기 크기에는 통째로 비율 스케일(fit)해 맞춘다.
///
/// ```swift
/// PortraitLockedLandscapeStage {
///     MyScreen()   // 874×402 기준으로 좌표를 잡으면 끝
/// }
/// ```
///
/// - Important: iPhone의 회전 방식 때문에 **시스템 UI(권한 팝업·`MPVolumeView`·공유 시트)는
///   회전되지 않아** 콘텐츠와 90° 어긋나 보인다. iPad는 자연 방향이라 이 문제가 없다.
///   해당 UI를 띄우는 화면은 ARCHITECTURE §2.5의 예외 처리를 따를 것.
/// - Note: iPad 전용 레이아웃(사운드홀을 크게 등)은 아직이다 — 지금은 iPhone 도화지를 그대로
///   키워 보여준다(위아래 여백 생김). 4:3 재배치는 SPEC §8 결정 후.
struct PortraitLockedLandscapeStage<Content: View>: View {
    let content: Content
    /// 콘텐츠가 좌표를 잡는 기준 가로 도화지. 지금 모든 화면이 iPhone 기준(874×402)으로 짜여 있다.
    var reference: CGSize
    /// 회전 여부를 정하는 기기 종류. 프리뷰·테스트에서 주입할 수 있게 열어둔다.
    private let deviceType: DeviceType

    init(
        reference: CGSize = LayoutTokens.phoneStage,
        deviceType: DeviceType = DeviceInfoProvider.currentDeviceType,
        @ViewBuilder content: () -> Content
    ) {
        self.reference = reference
        self.deviceType = deviceType
        self.content = content()
    }

    /// iPad는 이미 가로라 회전이 필요 없다. 그 외(iPhone 등)는 세로 고정이라 -90°로 가로를 만든다.
    private var rotatesToLandscape: Bool { deviceType != .iPad }

    var body: some View {
        GeometryReader { proxy in
            if rotatesToLandscape {
                rotatedStage(in: proxy)
            } else {
                naturalStage(in: proxy)
            }
        }
        .background(Color.gsStageBackground)
        .ignoresSafeArea()
    }

    /// 📱 iPhone — 세로 화면을 -90° 돌려 가로를 만든다. 그래서 가로/세로가 뒤바뀐다.
    @ViewBuilder
    private func rotatedStage(in proxy: GeometryProxy) -> some View {
        let stageSize = CGSize(width: proxy.size.height, height: proxy.size.width)
        let scale = LayoutTokens.scale(reference: reference, in: stageSize)

        // 세이프에어리어도 회전에 맞춰 한 칸씩 돌리고, 콘텐츠가 기준 좌표계에 있으므로
        // 배율로 나눠 같은 물리 거리를 가리키게 한다.
        let stageSafeArea = EdgeInsets(
            top: proxy.safeAreaInsets.leading / scale,
            leading: proxy.safeAreaInsets.bottom / scale,
            bottom: proxy.safeAreaInsets.trailing / scale,
            trailing: proxy.safeAreaInsets.top / scale
        )

        content
            .environment(\.landscapeStageSafeAreaInsets, stageSafeArea)
            .environment(\.stageMetrics, StageMetrics(reference: reference, scale: scale))
            .frame(width: reference.width, height: reference.height)
            .scaleEffect(scale)
            .frame(width: stageSize.width, height: stageSize.height)
            .rotationEffect(.degrees(-90))
            .frame(width: proxy.size.width, height: proxy.size.height)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .clipped()
    }

    /// 📲 iPad — 기기가 이미 가로다. 회전 없이 기준 도화지를 화면에 맞춘다.
    @ViewBuilder
    private func naturalStage(in proxy: GeometryProxy) -> some View {
        let scale = LayoutTokens.scale(reference: reference, in: proxy.size)

        let stageSafeArea = EdgeInsets(
            top: proxy.safeAreaInsets.top / scale,
            leading: proxy.safeAreaInsets.leading / scale,
            bottom: proxy.safeAreaInsets.bottom / scale,
            trailing: proxy.safeAreaInsets.trailing / scale
        )

        content
            .environment(\.landscapeStageSafeAreaInsets, stageSafeArea)
            .environment(\.stageMetrics, StageMetrics(reference: reference, scale: scale))
            .frame(width: reference.width, height: reference.height)
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .clipped()
    }
}
