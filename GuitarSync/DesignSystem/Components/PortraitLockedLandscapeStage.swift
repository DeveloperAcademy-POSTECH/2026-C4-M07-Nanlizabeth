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

/// 세로 고정 앱 안에서 가로 화면을 만드는 스테이지 (ARCHITECTURE §2.5 / 태스크 F1).
///
/// 두 가지 일을 한다:
/// 1. **회전** — 콘텐츠를 -90° 돌려 가로로 세운다.
/// 2. **스케일** — 콘텐츠를 `LayoutTokens.referenceStage`(852×393) 크기로 눕히고,
///    실제 기기 크기에 맞게 통째로 비율 축소/확대한다.
///
/// 덕분에 **화면 코드는 항상 852×393 도화지 하나만 생각하면 된다.**
///
/// ```swift
/// PortraitLockedLandscapeStage {
///     MyScreen()   // 852×393 기준으로 좌표를 잡으면 끝
/// }
/// ```
///
/// - Important: 회전 방식이라 **시스템 UI(권한 팝업·`MPVolumeView`·공유 시트)는 회전되지 않는다.**
///   실제 세로 방향으로 뜨므로 콘텐츠와 90° 어긋나 보인다. 해당 UI를 띄우는 화면은
///   ARCHITECTURE §2.5의 예외 처리 항목을 따를 것.
struct PortraitLockedLandscapeStage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            // 회전 후 기준이므로 가로/세로가 뒤바뀐다.
            let stageSize = CGSize(width: proxy.size.height, height: proxy.size.width)
            let scale = LayoutTokens.scale(for: stageSize)

            // 세이프에어리어도 회전에 맞춰 한 칸씩 돌리고,
            // 콘텐츠가 기준 좌표계에 있으므로 배율로 나눠 같은 물리 거리를 가리키게 한다.
            let stageSafeArea = EdgeInsets(
                top: proxy.safeAreaInsets.leading / scale,
                leading: proxy.safeAreaInsets.bottom / scale,
                bottom: proxy.safeAreaInsets.trailing / scale,
                trailing: proxy.safeAreaInsets.top / scale
            )

            content
                .environment(\.landscapeStageSafeAreaInsets, stageSafeArea)
                .environment(\.stageScale, scale)
                .frame(width: LayoutTokens.referenceStage.width, height: LayoutTokens.referenceStage.height)
                .scaleEffect(scale)
                .frame(width: stageSize.width, height: stageSize.height)
                .rotationEffect(.degrees(-90))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .clipped()
        }
        .background(Color(red: 0.02, green: 0.04, blue: 0.045))
        .ignoresSafeArea()
    }
}
