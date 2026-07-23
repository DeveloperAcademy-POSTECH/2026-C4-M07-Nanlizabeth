import SwiftUI

/// 화면 1 — 첫 실행 온보딩 (3장). (Figma 568-8814 · 568-38977 · 568-38981)
///
/// 세 장의 안내(음량 → 방해금지 → iPad 연결)를 넘겨 보고, 마지막 **Start**로 온보딩을 마친다.
/// 각 장은 Figma export 이미지를 통째 배경으로 쓴다(상단 페이지 점·일러스트·문구 포함).
/// 온보딩을 마치면 `AppRouter`가 홈으로 보내고, 첫 실행이면 튜토리얼이 이어진다.
///
/// - Note: 이전 볼륨·방해금지 카드(인터랙티브)는 디자인이 정적 안내로 바뀌어 이미지로 대체됐다.
struct OnboardingScreen: View {
    @EnvironmentObject private var router: AppRouter
    @State private var page = 0

    private let stage = LayoutTokens.phoneStage

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $page) {
                pageImage("OnboardingPage1").tag(0)
                pageImage("OnboardingPage2").tag(1)
                ZStack {
                    pageImage("OnboardingPage3")
                    // 이미지에 그려진 "Start" 위에 투명 탭 영역을 얹는다.
                    Button { router.completeOnboarding() } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .frame(width: 260, height: 58)
                    .position(x: stage.width / 2, y: 346)
                    .accessibilityLabel("온보딩 마치고 시작하기")
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // 원본 이미지에 포함된 인디케이터를 가리고, 페이지와 함께 움직이지 않는
            // 고정 인디케이터를 같은 자리에 별도 레이어로 표시한다.
            Color.gsStageBackground
                .frame(height: 55)
                .allowsHitTesting(false)

            pageIndicator
                .padding(.top, 26)
        }
        .frame(width: stage.width, height: stage.height)
        .ignoresSafeArea()
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        index == page
                            ? Color.gsTextPrimary
                            : Color.gsTextPrimary.opacity(0.32)
                    )
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func pageImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: stage.width, height: stage.height)
            .clipped()
    }
}

#Preview("온보딩") {
    PortraitLockedLandscapeStage {
        OnboardingScreen()
            .environmentObject(AppRouter())
    }
}
