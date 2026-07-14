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

struct PortraitLockedLandscapeStage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let stageSafeArea = EdgeInsets(
                top: proxy.safeAreaInsets.leading,
                leading: proxy.safeAreaInsets.bottom,
                bottom: proxy.safeAreaInsets.trailing,
                trailing: proxy.safeAreaInsets.top
            )

            content
                .environment(\.landscapeStageSafeAreaInsets, stageSafeArea)
                .frame(width: proxy.size.height, height: proxy.size.width)
                .rotationEffect(.degrees(-90))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .clipped()
        }
        .background(Color(red: 0.02, green: 0.04, blue: 0.045))
        .ignoresSafeArea()
    }
}
