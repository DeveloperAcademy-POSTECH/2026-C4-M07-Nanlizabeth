import SwiftUI

/// 라우터가 가리키는 화면을 그리는 유일한 곳. (ARCHITECTURE §3.9)
///
/// **화면을 추가·교체할 때 고치는 파일은 여기 하나다.** 뷰 안에서 다른 화면을 직접 띄우지 않는다.
///
/// ## 지금 상태 (2026-07-20, 태스크 F3)
/// 화면 9개가 전부 등록돼 있고, 아직 안 만든 4개는 `ScreenPlaceholder`가 자리를 잡고 있다.
/// U 레인은 **자기 화면의 case 한 줄만 바꾸면** 된다.
struct AppRootView: View {
    @StateObject private var router = AppRouter()

    /// ⚠️ 프로토타입 잔재. 넥·스트럼 화면(U2·U3)이 완성되면 이 뷰모델과
    /// `Features/Shared/` 폴더 전체가 사라진다.
    @StateObject private var prototypeViewModel = ScreenshotPrototypeViewModel()

    var body: some View {
        PortraitLockedLandscapeStage {
            ZStack {
                Color.gsStageBackground
                    .ignoresSafeArea()

                screen
            }
        }
        .environmentObject(router)
        .preferredColorScheme(.dark)
        // ⚠️ 프로토타입 다리 — 아래 두 개는 U2·U3와 함께 사라진다.
        // 프로토타입 화면은 자체 `screen` 값으로 이동하므로, 그걸 라우터 이동으로 옮겨준다.
        // (규약: 화면 전환은 반드시 라우터로 — ARCHITECTURE §5)
        .onChange(of: prototypeViewModel.screen) { _, screen in
            switch screen {
            case .main: break
            case .strumSelect: router.navigate(to: .strokeSelect)
            case .chordProgression: router.navigate(to: .progressionSelect)
            }
        }
        // 라우터로 메인에 돌아오면 프로토타입 쪽 상태도 되돌려, 다음 이동이 다시 감지되게 한다.
        .onChange(of: router.currentRoute) { _, route in
            if route == .neck || route == .strum {
                prototypeViewModel.screen = .main
            }
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch router.currentRoute {
        case .onboarding:
            OnboardingScreen()

        case .neck, .strum:
            // ⚠️ 임시 — 넥과 스트럼이 아직 프로토타입 한 화면에 같이 들어 있다.
            // U2(넥)·U3(스트럼)에서 각각 독립 화면으로 분리하며 이 case를 나눈다.
            MainInstrumentScreen(viewModel: prototypeViewModel)

        case .strokeSelect:
            StrumSelectScreen(
                onBack: router.back,
                onConfirm: router.back
            )

        case .progressionSelect:
            ChordProgressionScreen(
                selectedRoot: $prototypeViewModel.selectedChordRoot,
                onBack: router.back,
                onConfirm: router.back
            )

        case .progressionCustom:
            ProgressionCustomScreen()

        case .peerGuide:
            PeerGuideScreen()

        case .peerBrowse:
            PeerBrowseScreen()
        }
    }
}
