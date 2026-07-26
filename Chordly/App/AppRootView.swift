import SwiftUI
import UIKit

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
    /// 노래 선택으로 들어간 당시의 모드. 같은 곡이어도 코드/스트로크 드릴 화면이 다르다.
    @State private var selectedDrillMode: PrototypeMode = .chord

    /// 첫 실행 튜토리얼 — 온보딩 뒤에 실제 화면 위로 대화창을 얹어 단계를 진행한다.
    @StateObject private var tutorial = TutorialController()
    @State private var showsDeviceNamePrompt = false
    @State private var startsConnectionTutorialAfterNaming = false
    @State private var showsConnectionSuccess = false

    /// 첫 실행 튜토리얼은 왼손 코드 조작이 있는 iPhone에서만 진행한다.
    private var supportsTutorial: Bool {
        DeviceInfoProvider.currentDeviceType != .iPad
    }

    /// iPad **스트럼**만 Figma iPad 4:3 도화지(1366×1024)를 쓴다 — 배경 이미지가 화면을 꽉 채우도록.
    /// 나머지 화면·기기는 기존 iPhone 도화지(874×402) 그대로. (iPad 다른 화면들의 4:3 재배치는 이후 작업)
    private var stageReference: CGSize {
        let isPad = DeviceInfoProvider.currentDeviceType == .iPad
        let usesPadStrumStage =
            router.currentRoute == .strum
            || (router.currentRoute == .chordDrill && selectedDrillMode == .strum)
        return isPad && usesPadStrumStage ? LayoutTokens.padStage : LayoutTokens.phoneStage
    }

    var body: some View {
        PortraitLockedLandscapeStage(reference: stageReference) {
            ZStack {
                Color.gsStageBackground
                    .ignoresSafeArea()

                screen

                // 이미 완성된 화면 위에 튜토리얼 대화창을 얹는다. 대화창 밖 터치는 막지 않는다.
                if tutorial.isOverlayVisible,
                   supportsTutorial || tutorial.isConnectionTutorial {
                    TutorialOverlay(tutorial: tutorial)
                }

                if showsDeviceNamePrompt {
                    DeviceNamePrompt(initialName: peerConnect.localDisplayName) { name in
                        guard peerConnect.setDisplayName(name) else { return }
                        showsDeviceNamePrompt = false
                        if startsConnectionTutorialAfterNaming {
                            startsConnectionTutorialAfterNaming = false
                            tutorial.startConnectionTutorial()
                        }
                    }
                }

                if let peerName = peerConnect.pendingInvitationPeerName {
                    PeerInvitationPopup(
                        peerName: peerName,
                        onAccept: { peerConnect.respondToInvitation(accept: true) },
                        onDecline: { peerConnect.respondToInvitation(accept: false) }
                    )
                }

                if showsConnectionSuccess {
                    PeerConnectedPopup(
                        peerName: peerConnect.connectedPeerName ?? "상대 디바이스",
                        onDismiss: { showsConnectionSuccess = false }
                    )
                }
            }
            .overlayPreferenceValue(BPMButtonBoundsPreferenceKey.self) { buttonAnchor in
                RootBPMPopover(
                    buttonAnchor: buttonAnchor,
                    viewModel: prototypeViewModel,
                    peer: peerConnect,
                    tutorial: tutorial
                )
            }
        }
        .environmentObject(router)
        .preferredColorScheme(.dark)
        // ⚠️ 프로토타입 다리 — 아래 세 개는 U2·U3와 함께 사라진다.
        // 프로토타입 화면은 자체 `screen`·`mode` 값으로 도는데, 라우터가 정답이어야 하므로 이어 붙인다.
        // (규약: 화면 전환은 반드시 라우터로 — ARCHITECTURE §5)
        .onAppear {
            syncPrototype(to: router.currentRoute)
            updateIdleTimer(for: router.currentRoute)
            startTutorialIfEligible(on: router.currentRoute)
            if DeviceInfoProvider.currentDeviceType == .iPad,
               !peerConnect.hasCustomDisplayName {
                showsDeviceNamePrompt = true
            }
        }
        .onChange(of: prototypeViewModel.screen) { _, screen in
            switch screen {
            case .main: break
            case .strumSelect:
                router.navigate(to: .strokeSelect)
                // route onChange 체이닝 타이밍에 의존하지 않도록 튜토리얼에 직접 알린다.
                tutorial.handle(.navigated(.strokeSelect))
            case .chordProgression: router.navigate(to: .progressionSelect)
            }
        }
        .onChange(of: router.currentRoute) { _, route in
            syncPrototype(to: route)
            updateIdleTimer(for: route)
            tutorial.handle(.navigated(route))     // 이동 단계 검증(스트로크 선택·스트럼)
            startTutorialIfEligible(on: route)     // 온보딩 마치면 튜토리얼 시작
        }
        // iPad 연결·스트로크 패턴 선택 단계 검증.
        .onChange(of: peerConnect.isConnected) { _, connected in
            if connected {
                tutorial.handle(.connected)
                showsConnectionSuccess = true
                applyConnectedRole(peerConnect.role)
                startConnectedSongTutorialIfEligible()
            } else {
                showsConnectionSuccess = false
                router.returnHome()
                startTutorialIfEligible(on: router.currentRoute)
            }
        }
        .onChange(of: peerConnect.role) { _, role in
            guard peerConnect.isConnected else { return }
            applyConnectedRole(role)
            startConnectedSongTutorialIfEligible()
        }
        // 연결된 iPad가 튕기면 → iPhone 튜토리얼 마지막 단계(“iPad로 치기”)를 완료 대기 상태로.
        .onChange(of: peerConnect.remoteStrumTick) { _, _ in
            tutorial.handle(.remoteStrummed)
        }
        .onChange(of: strumSelect.selectedID) { _, id in
            if id != nil { tutorial.handle(.patternSelected) }
        }
        .onChange(of: peerConnect.sharedSongSelectionTick) { _, _ in
            guard peerConnect.isConnected,
                  peerConnect.role == .strumming,
                  let title = peerConnect.sharedSongTitle,
                  let song = PracticeSongData.songs.first(where: { $0.title == title })
            else { return }

            selectedDrillSong = song
            selectedDrillMode = .strum
            router.replaceRoot(with: .chordDrill)
        }
        .onChange(of: peerConnect.pendingInvitationPeerName) { _, peerName in
            if peerName != nil {
                prototypeViewModel.showBPM = false
            }
        }
    }

    /// 연주 화면에서는 화면이 꺼지지 않게 한다 — 오토락으로 앱이 백그라운드로 가면
    /// Multipeer 세션이 끊겨 합주가 중단되기 때문. 연주 화면을 벗어나면 다시 켜 배터리를 아낀다.
    private func updateIdleTimer(for route: AppRoute) {
        UIApplication.shared.isIdleTimerDisabled = route.isPerformanceScreen
    }

    /// 튜토리얼 시작 자격 판정. **iPad는 별도 튜토리얼이 없다** (코드 짚기 0단계가 iPad엔 불가능해
    /// 영원히 멈춘다) — iPhone에서 온보딩을 마친 뒤에만 시작한다.
    private func startTutorialIfEligible(on route: AppRoute) {
        guard supportsTutorial, route != .onboarding else { return }
        if route == .neck, !peerConnect.isConnected {
            tutorial.startIPhoneTutorialAfterConnectionIfNeeded()
        }
        tutorial.startIfNeeded()
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
            OnboardingScreen { path in
                switch path {
                case .iPhone:
                    tutorial.prepare(for: .iPhone)
                    router.completeOnboarding(startingAt: .neck)
                case .iPadConnection:
                    router.completeOnboarding(startingAt: .neck)
                    beginConnectionTutorial()
                }
            }

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
                    if tutorial.shouldOfferConnectionTutorial {
                        beginConnectionTutorial()
                        return false
                    }
                    return true
                },
                // 모드 토글이 **라우터 route까지** 바꾼다 — 그래야 선택·뒤로가기가 그 모드로 돌아온다.
                onModeChange: { mode in
                    prototypeViewModel.showBPM = false
                    let route: AppRoute = mode == .chord ? .neck : .strum
                    router.replaceRoot(with: route)
                    tutorial.handle(.navigated(route))   // 튜토리얼: 스트로크 모드 이동 직접 검증
                },
                // 노래 드릴 연습으로 진입 — 현재 코드/스트로크 모드를 기억한 뒤 곡을 고른다.
                onStartDrill: {
                    selectedDrillMode = peerConnect.isConnected ? .chord : prototypeViewModel.mode
                    router.navigate(to: .chordDrillSongSelect)
                },
                // 튜토리얼: 넥 목표 코드 표시 + 짚기·튕기기 동작 검증.
                tutorial: supportsTutorial ? tutorial : nil
            )

        case .chordDrillSongSelect:
            ChordDrillSongSelectScreen(
                songs: PracticeSongData.songs,
                onBack: router.back,
                onSelect: { song in
                    selectedDrillSong = song
                    if peerConnect.isConnected {
                        guard peerConnect.role == .fingering else { return }
                        selectedDrillMode = .chord
                        peerConnect.selectSharedSong(title: song.title)
                    }
                    tutorial.handle(.songSelected)
                    router.navigate(to: .chordDrill)
                }
            )

        case .chordDrill:
            ChordDrillScreen(
                song: selectedDrillSong ?? PracticeSongData.songs[0],
                mode: selectedDrillMode,
                peer: peerConnect
            )

        case .strokeSelect:
            StrumSelectScreen(
                viewModel: strumSelect,
                onBack: router.back,
                onConfirm: router.back,
                tutorialHighlight: tutorial.highlightTarget
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

    private func beginConnectionTutorial() {
        if !peerConnect.hasCustomDisplayName {
            startsConnectionTutorialAfterNaming = true
            showsDeviceNamePrompt = true
        } else {
            tutorial.startConnectionTutorial()
        }
    }

    private func applyConnectedRole(_ role: PeerHandRole) {
        let route: AppRoute = role == .fingering ? .neck : .strum
        router.replaceRoot(with: route)
    }

    private func startConnectedSongTutorialIfEligible() {
        tutorial.startConnectedSongTutorialIfNeeded(
            isRequester: peerConnect.isConnectionRequester && peerConnect.role == .fingering
        )
    }
}

private struct RootBPMPopover: View {
    @Environment(\.landscapeStageSafeAreaInsets) private var stageSafeArea

    let buttonAnchor: Anchor<CGRect>?
    @ObservedObject var viewModel: ScreenshotPrototypeViewModel
    @ObservedObject var peer: PeerConnectViewModel
    @ObservedObject var tutorial: TutorialController

    var body: some View {
        if viewModel.showBPM,
           viewModel.isControlBarExpanded,
           !viewModel.isPlaying,
           !peer.isConnected,
           let buttonAnchor {
            GeometryReader { proxy in
                let buttonFrame = proxy[buttonAnchor]
                let popoverWidth: CGFloat = 365
                let desiredX = buttonFrame.midX - popoverWidth / 2
                let popoverX = min(
                    max(stageSafeArea.leading, desiredX),
                    proxy.size.width - stageSafeArea.trailing - popoverWidth
                )
                let arrowOffset = buttonFrame.midX - (popoverX + popoverWidth / 2)

                BPMPopover(
                    bpm: $viewModel.bpm,
                    arrowOffsetX: arrowOffset,
                    highlightsNumber: tutorial.highlightTarget == .bpmNumber,
                    onCommit: { value in
                        tutorial.handle(.bpmCommitted(Int(value.rounded())))
                    },
                    onDismiss: {
                        viewModel.showBPM = false
                    }
                )
                .offset(x: popoverX, y: buttonFrame.maxY + 12)
            }
        }
    }
}
