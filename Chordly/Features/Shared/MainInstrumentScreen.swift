import SwiftUI

struct MainInstrumentScreen: View {
    @Environment(\.landscapeStageSafeAreaInsets) private var stageSafeArea

    @ObservedObject var viewModel: ScreenshotPrototypeViewModel
    /// 연결·운지 송수신을 담당하는 단일 세션. (모드 C)
    @ObservedObject var peer: PeerConnectViewModel

    @StateObject private var strumViewModel = GuitarStrumViewModel()

    /// 모드 A(넥 + 자동 스트럼). 엔진·운지상태를 하나로 공유해 조립한 컨트롤러.
    @StateObject private var chordMode = ChordModeController()

    /// 모드 B의 자동 왼손 — 고른 코드진행을 BPM에 맞춰 짚어준다. 스트럼 화면이 이 코드로 소리 낸다.
    @StateObject private var strumProgression = ChordProgressionPlayer()
    @State private var isPeerPopoverPresented = false

    /// 스트로크 선택(U4)에서 고른 주법. 재생 시 자동 스트럼이 이걸 긁는다.
    var selectedStrumPattern: StrumPattern?

    /// 진행 선택(U5)에서 고른 코드진행. 스트럼 모드에서 재생하면 이게 BPM대로 자동으로 짚힌다.
    var selectedProgression: ChordProgression?

    /// 연결 버튼(🔗)을 눌렀을 때. 기기 찾기 화면으로 이동한다 (AppRootView가 라우팅).
    var onPeerConnect: () -> Void = {}

    /// 코드/스트로크 모드를 바꿀 때. **라우터 route까지 바꾼다** — 안 그러면 뒤로가기가 넥으로 샌다.
    var onModeChange: (PrototypeMode) -> Void = { _ in }

    /// 코드 드릴 연습으로 진입할 때 (넥 화면에서만 노출). AppRootView가 라우팅한다.
    var onStartDrill: () -> Void = {}

    /// 첫 실행 튜토리얼. 있으면 넥에 목표 코드를 표시하고, 짚기·튕기기 동작을 튜토리얼에 알린다.
    var tutorial: TutorialController?

    /// 이 기기. iPad는 모드 토글을 숨기고 항상 스트로크만 한다.
    var deviceType: DeviceType = DeviceInfoProvider.currentDeviceType

    private var isPad: Bool { deviceType == .iPad }

    /// 넥 포지션 컨트롤(슬라이더)이 놓이는 자리. 지판이 시작되는 y=68보다 위쪽의
    /// 상단 안전영역 안에 들어가도록 작게 두며, 이 영역은 넥 터치에서 제외된다.
    private static let neckPositionBarSize = CGSize(width: 120, height: 36)

    private var neckPositionBarRegion: CGRect {
        CGRect(
            x: stageSafeArea.leading - 44,
            y: stageSafeArea.top,
            width: Self.neckPositionBarSize.width,
            height: Self.neckPositionBarSize.height
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            instrument
                .zIndex(0)

            TopControlBar(
                mode: viewModel.mode,
                isPlaying: viewModel.isPlaying,
                isExpanded: viewModel.isControlBarExpanded,
                peerButtonState: peerButtonState,
                actionTitle: viewModel.actionTitle,
                showsModeToggle: !isPad,
                // BPM은 **일시정지 중에만** 바꾼다 — 재생 중엔 잠근다.
                bpmEnabled: !viewModel.isPlaying,
                // 코드 모드에서만 연결 버튼 왼쪽에 드릴 진입 버튼이 뜬다 (TopControlBar가 모드로 거른다).
                onStartDrill: isPad ? nil : onStartDrill,
                tutorialHighlight: tutorial?.highlightTarget,
                onModeChange: onModeChange,
                onPeer: togglePeerPopover,
                onAction: viewModel.openActionScreen,
                onTogglePlayback: viewModel.togglePlayback,
                onToggleBPM: { if !viewModel.isPlaying { viewModel.toggleBPM() } },
                onToggleControls: viewModel.toggleControls
            )
            .padding(.top, max(20, stageSafeArea.top))
            .padding(.leading, stageSafeArea.leading)
            .padding(.trailing, stageSafeArea.trailing)
            // 기타의 전체 화면 UIKit 멀티터치 레이어보다 항상 위에서 버튼 입력을 받는다.
            .zIndex(10)

            if isPeerPopoverPresented {
                if !isPad {
                    PeerQuickConnectPopover(viewModel: peer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, peerPopoverRegion.minX)
                        .padding(.top, peerPopoverRegion.minY)
                        .zIndex(12)
                }
            }

            // 재생 중엔 BPM 팝오버를 감춘다 (일시정지 상태에서만 조절 가능).
            if viewModel.showBPM && viewModel.isControlBarExpanded && !viewModel.isPlaying {
                BPMPopover(bpm: $viewModel.bpm)
                    .padding(.top, max(88, stageSafeArea.top))
                    .padding(.trailing, max(100, stageSafeArea.trailing))
                    .zIndex(11)
            }

            #if DEBUG
            if viewModel.mode == .strum {
                DebugAudioEngineToggle(viewModel: strumViewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, max(20, stageSafeArea.leading))
                    .padding(.bottom, max(20, stageSafeArea.bottom))
            }
            #endif
        }
        .overlayPreferenceValue(PeerButtonBoundsPreferenceKey.self) { buttonAnchor in
            if isPad, isPeerPopoverPresented, let buttonAnchor {
                GeometryReader { proxy in
                    let buttonFrame = proxy[buttonAnchor]
                    let popoverWidth = InstrumentControlHitRegion.peerPopover.width
                    let centeredX = buttonFrame.midX - popoverWidth / 2
                    let popoverX = min(
                        max(stageSafeArea.leading, centeredX),
                        LayoutTokens.padStage.width - stageSafeArea.trailing - popoverWidth
                    )

                    ZStack(alignment: .topLeading) {
                        PeerQuickConnectPopover(viewModel: peer)
                            .offset(
                                x: popoverX,
                                y: buttonFrame.maxY + 8
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .zIndex(12)
            }
        }
        // 재생 버튼(▶/⏸)으로 자동 연주를 시작·정지한다.
        .onChange(of: viewModel.isPlaying) { _, playing in
            if playing { viewModel.showBPM = false }   // 재생 시작하면 BPM 팝오버 닫기
            refreshAuto()
        }
        // 연결 여부에 따라 자동 연주를 껐다(모드 C) 켰다(모드 A·B) 한다.
        .onChange(of: peer.isConnected) { _, connected in
            chordMode.setConnected(connected)
            refreshAuto()
            if connected {
                isPeerPopoverPresented = false
            }
        }
    }

    /// 지금 모드의 자동 연주를 조건에 맞게 켜거나 끈다.
    private func refreshAuto() {
        switch viewModel.mode {
        case .chord: refreshChordStrum()
        case .strum: refreshStrumProgression()
        }
    }

    /// 코드 모드(모드 A)의 자동 주법. **재생 중이고 연결 안 됐을 때만** 돈다.
    /// (짚기 자체는 무음이고, 이 자동 주법이 짚은 코드로 소리 낸다.)
    private func refreshChordStrum() {
        guard !peer.isConnected, viewModel.isPlaying else {
            chordMode.stop()
            return
        }
        chordMode.play(pattern: patternToPlay, bpm: viewModel.bpm)
    }

    /// 스트럼 모드(모드 B)의 자동 코드진행. **재생 중이고 진행을 골랐고 연결 안 됐을 때만** 돈다.
    private func refreshStrumProgression() {
        guard !peer.isConnected, viewModel.isPlaying, let progression = selectedProgression else {
            strumProgression.stop()
            return
        }
        strumProgression.start(progression: progression, bpm: viewModel.bpm, looping: true)
        // 첫 코드를 즉시 반영해 둔다 (클럭 첫 틱을 기다리지 않고 바로 그 코드로 소리 나게).
        if let first = progression.chord(atBar: 0) {
            strumViewModel.updateFingering(first.fingering.frets)
        }
    }

    /// 지금 자동 스트럼에 쓸 주법. 고른 게 없으면 첫 프리셋 → 최후 기본값.
    private var patternToPlay: StrumPattern {
        selectedStrumPattern ?? StrumPatternLibrary().presets.first ?? .fallback
    }

    private var peerButtonState: PrototypePeerButtonState {
        peer.isConnected ? .connected : .disconnected
    }

    private var instrumentHitRegions: [CGRect] {
        isPeerPopoverPresented
            ? [InstrumentControlHitRegion.topBar, peerPopoverRegion]
            : [InstrumentControlHitRegion.topBar]
    }

    /// iPhone은 기존 위치를 유지한다. iPad에서는 우측 상단바의 첫 버튼인 연결 버튼 바로 아래에
    /// 팝오버를 맞추고, 실제 표시 위치와 기타 터치 제외 영역이 같은 사각형을 공유한다.
    private var peerPopoverRegion: CGRect {
        guard isPad else {
            return InstrumentControlHitRegion.peerPopover
        }

        return CGRect(
            x: LayoutTokens.padStage.width
                - stageSafeArea.trailing
                - InstrumentControlHitRegion.peerPopover.width,
            y: stageSafeArea.top + 54,
            width: InstrumentControlHitRegion.peerPopover.width,
            height: InstrumentControlHitRegion.peerPopover.height
        )
    }

    private func togglePeerPopover() {
        isPeerPopoverPresented.toggle()
        if isPeerPopoverPresented, !peer.isConnected {
            peer.startBrowsing()
        }
    }

    @ViewBuilder
    private var instrument: some View {
        switch viewModel.mode {
        case .chord:
            // 모드 A/C — 넥으로 짚는다. **짚기 자체는 무음**이고, 단독이면 고른 주법이 BPM대로
            // 자동으로 긁으며 그 코드로 소리 낸다 (스트로크 모드가 진행을 자동으로 돌리는 것과 대칭).
            // 연결되면 자동 스트럼을 멈추고, 운지는 상대(iPad)로 전송돼 거기서 소리가 난다.
            NeckScreen(
                viewModel: chordMode.neck,
                onFingeringChanged: { fingering in
                    peer.sendFingering(fingering)
                    tutorial?.handle(.chordFretted(fingering))   // 튜토리얼: 첫 코드 짚기 검증
                },
                // 튜토리얼 단계면 목표 코드를 라임 점으로 표시한다.
                targetFingering: tutorial?.neckTargetChord?.fingering,
                targetFingers: tutorial?.neckTargetChord?.fingers ?? [],
                // #36 연결 팝오버 영역 + 내 포지션 바 영역을 프렛 짚기에서 제외.
                excludedHitRegions: instrumentHitRegions,
                extraExcludedRegions: [neckPositionBarRegion]
            )
                .ignoresSafeArea()
                // 넥을 사운드홀 쪽 높은 프렛으로 옮기는 컨트롤 (슬라이더 ⟷ 모션 A/B).
                .overlay {
                    NeckPositionControl(slider: chordMode.sliderPosition)
                        .frame(
                            width: neckPositionBarRegion.width,
                            height: neckPositionBarRegion.height
                        )
                        .position(x: neckPositionBarRegion.midX, y: neckPositionBarRegion.midY)
                }
                .onAppear {
                    chordMode.start()
                    chordMode.setConnected(peer.isConnected)
                    // 튜토리얼 "스트로크 체험" 단계: 자동재생을 켜 고른 주법이 계속 돌게 한다.
                    // (isPlaying 변경이 onChange→refreshAuto로 자동 주법을 켠다. 안 켜면 짚을 때
                    //  개별 발음만 한 번 나고 스트로크를 체험할 수 없다.)
                    if tutorial?.shouldAutoPlayStrum == true {
                        viewModel.isPlaying = true
                    } else {
                        refreshChordStrum()   // 단독이면 자동 주법이 바로 돌기 시작
                    }
                }
                // 주법을 새로 고르면 그 주법으로 바로 갈아탄다.
                .onChange(of: selectedStrumPattern) { _, _ in
                    refreshChordStrum()
                }
                .onDisappear {
                    chordMode.end()
                    viewModel.isPlaying = false
                }
        case .strum:
            // 스트럼 — 단독(모드 B)이거나 연결됨(모드 C). 연결되면 상대(iPhone)가 짚은 운지로 소리 난다.
            // 그리고 내가 튕길 때마다 그 세기를 상대(iPhone)로 보내 거기서 진동이 나게 한다.
            GuitarStrumView(
                viewModel: strumViewModel,
                isPad: isPad,
                excludedHitRegions: instrumentHitRegions
            )
                .ignoresSafeArea()
                .onAppear {
                    // 연결됐으면 상대 운지로, 아니면 고른 진행을 자동으로 돌린다.
                    if peer.isConnected {
                        strumViewModel.updateFingering(peer.receivedFingering.frets)
                    } else {
                        refreshStrumProgression()
                    }
                }
                // 모드 C: 상대(iPhone)가 짚은 운지로 소리 난다.
                .onChange(of: peer.receivedFingering) { _, fingering in
                    guard peer.isConnected else { return }
                    strumViewModel.updateFingering(fingering.frets)
                }
                // 진행을 새로 고르면 그 진행으로 바로 갈아탄다.
                .onChange(of: selectedProgression) { _, _ in
                    refreshStrumProgression()
                }
                // 모드 B: 자동 코드진행이 BPM대로 코드를 바꾸면 그 코드로 소리 난다.
                .onReceive(strumProgression.chordChanged) { chord in
                    guard !peer.isConnected else { return }
                    strumViewModel.updateFingering(chord.fingering.frets)
                }
                // 내가 튕길 때마다 그 세기를 상대(iPhone)로 보내 거기서 진동이 나게 한다. (모드 C)
                .onReceive(strumViewModel.strumPerformed) { velocity in
                    peer.sendStrumHaptic(velocity: velocity)
                    tutorial?.handle(.strummed)   // 튜토리얼: 마지막 단계(줄 튕기기) 검증
                }
                .onDisappear { strumProgression.stop() }
        }
    }
}

// MARK: - 넥 포지션 컨트롤 (사운드홀 쪽 프렛으로 이동)

/// 넥을 사운드홀 쪽 높은 프렛으로 옮기는 컨트롤 — **슬라이더**로 포지션(1fr…8fr)을 정한다.
/// (docs/PLAN-neck-position)
///
/// - Note: 모션 입력은 아직 불안정해서 **UI에선 숨겼다.** 기능(`MotionNeckPositionProvider`·A/B
///   전환)은 그대로 남아 있어, 안정화되면 토글만 다시 노출하면 된다.
private struct NeckPositionControl: View {
    @ObservedObject var slider: SliderNeckPositionProvider

    var body: some View {
        HStack(spacing: 6) {
            Text("\(slider.position + 1)fr")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 26, alignment: .leading)

            Slider(
                value: Binding(get: { slider.sliderValue }, set: { slider.sliderValue = $0 }),
                in: 0...Double(max(slider.maxPosition, 1)),
                step: 1
            )
            .tint(Color.gsAccent)
            // 넥과 방향을 맞춘다: **오른쪽=너트(1프렛), 왼쪽=사운드홀(높은 프렛)**.
            // 손잡이가 오른쪽에서 시작해 사운드홀 쪽(왼쪽)으로 움직인다.
            .scaleEffect(x: -1, y: 1)
            .accessibilityLabel("프렛 위치")
            .accessibilityValue("\(slider.position + 1)프렛")
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background {
            Color.clear
                .glassEffect(.regular, in: .capsule)
                .allowsHitTesting(false)
        }
    }
}
