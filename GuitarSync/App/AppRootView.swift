import SwiftUI

/// 라우터가 가리키는 화면을 그리는 유일한 곳. (ARCHITECTURE §3.9)
///
/// **화면을 추가·교체할 때 고치는 파일은 여기 하나다.** 뷰 안에서 다른 화면을 직접 띄우지 않는다.
///
/// ## 지금 상태
/// 화면이 전부 실구현으로 등록돼 있다. 넥·스트럼은 아직 프로토타입 셸(`MainInstrumentScreen`)에
/// 함께 들어 있고, 나머지(온보딩·선택·커스텀·연결)는 각자 독립 화면이다.
struct AppRootView: View {
    @StateObject private var router = AppRouter()

    /// 연결 화면 2개가 함께 쓴다 — 가이드에서 기기 찾기로 넘어가도 상태가 이어져야 한다.
    @StateObject private var peerConnect = PeerConnectViewModel()

    /// 고른 주법은 **화면보다 오래 살아야 한다** — 목록에 들어갔다 나와도 선택이 유지되도록
    /// 여기에 둔다. 실제 연주에 물리는 건 L5(코디네이터)에서.
    @StateObject private var strumSelect = StrumSelectViewModel()

    /// 진행 선택(U5)·커스텀(U6)이 한 라이브러리를 공유하도록 묶은 것.
    @StateObject private var progression = ProgressionFlowModel()

    /// ⚠️ 프로토타입 잔재. 넥·스트럼 화면(U2·U3)이 완성되면 이 뷰모델과
    /// `Features/Shared/` 폴더 전체가 사라진다.
    @StateObject private var prototypeViewModel = ScreenshotPrototypeViewModel()

    /// 코드 드릴에서 고른 연습곡. 노래 선택 화면 → 드릴 화면으로 넘겨준다.
    @State private var selectedDrillSong: PracticeSong?

    /// iPad **스트럼**만 Figma iPad 4:3 도화지(1366×1024)를 쓴다 — 배경 이미지가 화면을 꽉 채우도록.
    /// 나머지 화면·기기는 기존 iPhone 도화지(874×402) 그대로. (iPad 다른 화면들의 4:3 재배치는 이후 작업)
    private var stageReference: CGSize {
        let isPad = DeviceInfoProvider.currentDeviceType == .iPad
        return isPad && router.currentRoute == .strum ? LayoutTokens.padStage : LayoutTokens.phoneStage
    }

    var body: some View {
        PortraitLockedLandscapeStage(reference: stageReference) {
            ZStack {
                Color.gsStageBackground
                    .ignoresSafeArea()

                screen
            }
        }
        .environmentObject(router)
        .preferredColorScheme(.dark)
        // ⚠️ 프로토타입 다리 — 아래 세 개는 U2·U3와 함께 사라진다.
        // 프로토타입 화면은 자체 `screen`·`mode` 값으로 도는데, 라우터가 정답이어야 하므로 이어 붙인다.
        // (규약: 화면 전환은 반드시 라우터로 — ARCHITECTURE §5)
        .onAppear { syncPrototype(to: router.currentRoute) }
        .onChange(of: prototypeViewModel.screen) { _, screen in
            switch screen {
            case .main: break
            case .strumSelect: router.navigate(to: .strokeSelect)
            case .chordProgression: router.navigate(to: .progressionSelect)
            }
        }
        .onChange(of: router.currentRoute) { _, route in
            syncPrototype(to: route)
        }
    }

    /// 라우터 → 프로토타입 상태. **라우터가 정답이다.**
    ///
    /// 이걸 안 하면 iPad에서 라우터는 `.strum`인데 프로토타입은 기본값 `.chord`라
    /// **iPad에 기타넥이 뜬다** (iPad는 왼손을 안 맡는데도).
    private func syncPrototype(to route: AppRoute) {
        switch route {
        case .neck:
            prototypeViewModel.mode = .chord
            prototypeViewModel.screen = .main
        case .strum:
            prototypeViewModel.mode = .strum
            prototypeViewModel.screen = .main
        default:
            break
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
            //
            // ⚠️ **iPad에서는 레이아웃이 맞지 않는다.** 이 화면은 iPhone 874×402 기준으로
            // 짜여 있는데 iPad 도화지는 1366×1024라 여백이 크게 남는다.
            // iPad용 스트럼 레이아웃은 U3에서 Figma `iPad Pro 12.9" - 3/4/5`를 보고 새로 짠다
            // (사운드홀을 중앙에 크게, 줄이 화면 전체를 관통하는 배치).
            MainInstrumentScreen(
                viewModel: prototypeViewModel,
                peer: peerConnect,
                selectedStrumPattern: strumSelect.selectedPattern,
                selectedProgression: progression.select.selectedProgression,
                // 처음이면 가이드부터, 봤으면 바로 기기 찾기로. (SPEC 플로우3)
                onPeerConnect: {
                    router.navigate(to: peerConnect.shouldShowGuide ? .peerGuide : .peerBrowse)
                },
                // 모드 토글이 **라우터 route까지** 바꾼다 — 그래야 선택·뒤로가기가 그 모드로 돌아온다.
                onModeChange: { mode in
                    prototypeViewModel.showBPM = false
                    router.replaceRoot(with: mode == .chord ? .neck : .strum)
                },
                // 넥(모드 A)에서 코드 드릴 연습으로 진입 — 먼저 노래를 고른다.
                onStartDrill: { router.navigate(to: .chordDrillSongSelect) }
            )

        case .chordDrillSongSelect:
            ChordDrillSongSelectScreen(
                songs: PracticeSongData.songs,
                onBack: router.back,
                onSelect: { song in
                    selectedDrillSong = song
                    router.navigate(to: .chordDrill)
                }
            )

        case .chordDrill:
            ChordDrillScreen(song: selectedDrillSong ?? PracticeSongData.songs[0])

        case .strokeSelect:
            StrumSelectScreen(
                viewModel: strumSelect,
                onBack: router.back,
                onConfirm: router.back
            )

        case .progressionSelect:
            ProgressionSelectScreen(
                viewModel: progression.select,
                onBack: router.back,
                onConfirm: router.back,
                onCreateCustom: { router.navigate(to: .progressionCustom) }
            )

        case .progressionCustom:
            ProgressionCustomScreen(
                viewModel: progression.custom,
                onBack: router.back,
                onSaved: router.back
            )

        case .peerGuide:
            PeerGuideScreen(viewModel: peerConnect)

        case .peerBrowse:
            PeerBrowseScreen(viewModel: peerConnect)
        }
    }
}
