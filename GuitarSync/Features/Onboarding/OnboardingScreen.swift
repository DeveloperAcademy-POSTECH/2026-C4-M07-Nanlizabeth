import SwiftUI

/// 화면 1 — 첫 실행 안내. (SPEC 플로우 4 / ARCHITECTURE §3.10 · ROADMAP 태스크 U1)
///
/// ## 만들 때 챙길 것
/// - **볼륨**: 앱이 강제로 못 바꾼다. 현재 볼륨을 읽어(`AVAudioSession.outputVolume`)
///   낮으면 안내 카드 + `MPVolumeView` 슬라이더를 준다.
/// - **방해금지**: 앱이 켜줄 수 없다. "제어 센터에서 이렇게 켜세요" **안내만**.
/// - **무음 스위치·화면 꺼짐**: 앱이 알아서 처리하므로 온보딩에서 다루지 않는다.
/// - ⚠️ `MPVolumeView`는 UIKit 뷰라 스테이지 회전을 따라오지 않는다 → ARCHITECTURE §2.5 예외 처리.
struct OnboardingScreen: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(spacing: 20) {
            ScreenPlaceholder(
                route: .onboarding,
                task: "U1",
                hint: "볼륨 카드(슬라이더) + 방해금지 안내"
            )

            // 진짜 온보딩이 생기기 전까지 앱을 쓸 수 있게 하는 임시 통로.
            // U1에서 진짜 "시작하기" 버튼으로 바꾼다.
            Button("건너뛰고 시작하기") {
                router.completeOnboarding()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Capsule().fill(.white))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
