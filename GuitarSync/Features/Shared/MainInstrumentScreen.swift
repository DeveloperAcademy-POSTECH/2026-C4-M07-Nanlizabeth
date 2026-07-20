import SwiftUI

struct MainInstrumentScreen: View {
    @ObservedObject var viewModel: ScreenshotPrototypeViewModel
    /// 연결·운지 송수신을 담당하는 단일 세션. (모드 C)
    @ObservedObject var peer: PeerConnectViewModel

    @StateObject private var strumViewModel = GuitarStrumViewModel()

    /// 모드 A(넥 + 자동 스트럼). 엔진·운지상태를 하나로 공유해 조립한 컨트롤러.
    @StateObject private var chordMode = ChordModeController()

    /// 스트로크 선택(U4)에서 고른 주법. 재생 시 자동 스트럼이 이걸 긁는다.
    var selectedStrumPattern: StrumPattern?

    /// 연결 버튼(🔗)을 눌렀을 때. 기기 찾기 화면으로 이동한다 (AppRootView가 라우팅).
    var onPeerConnect: () -> Void = {}

    /// 이 기기. iPad는 모드 토글을 숨기고 항상 스트로크만 한다.
    var deviceType: DeviceType = DeviceInfoProvider.currentDeviceType

    private var isPad: Bool { deviceType == .iPad }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            instrument

            TopControlBar(
                mode: viewModel.mode,
                isPlaying: viewModel.isPlaying,
                isExpanded: viewModel.isControlBarExpanded,
                peerButtonState: peerButtonState,
                actionTitle: viewModel.actionTitle,
                showsModeToggle: !isPad,
                onModeChange: viewModel.toggleMode(_:),
                onPeer: onPeerConnect,
                onAction: viewModel.openActionScreen,
                onTogglePlayback: viewModel.togglePlayback,
                onToggleBPM: viewModel.toggleBPM,
                onToggleControls: viewModel.toggleControls
            )
            .padding(.top, 20)
            .padding(.leading, 20)
            .padding(.trailing, 60)

            if viewModel.showBPM && viewModel.isControlBarExpanded {
                BPMPopover(bpm: $viewModel.bpm)
                    .padding(.top, 88)
                    .padding(.trailing, 162)
            }

            #if DEBUG
            if viewModel.mode == .strum {
                DebugAudioEngineToggle(viewModel: strumViewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 20)
                    .padding(.bottom, 20)
            }
            #endif
        }
        // 재생 버튼(▶)이 isPlaying을 토글한다. 코드 모드면 자동 스트럼을 켜고 끈다.
        .onChange(of: viewModel.isPlaying) { _, playing in
            guard viewModel.mode == .chord else { return }
            if playing {
                chordMode.play(pattern: patternToPlay, bpm: viewModel.bpm)
            } else {
                chordMode.stop()
            }
        }
        // 연결되면 이 iPhone은 무음+진동, 자동 스트럼 정지 (소리는 iPad에서).
        .onChange(of: peer.isConnected) { _, connected in
            chordMode.setConnected(connected)
            if connected { viewModel.isPlaying = false }
        }
    }

    /// 지금 자동 스트럼에 쓸 주법. 고른 게 없으면 첫 프리셋 → 최후 기본값.
    private var patternToPlay: StrumPattern {
        selectedStrumPattern ?? StrumPatternLibrary().presets.first ?? .fallback
    }

    private var peerButtonState: PrototypePeerButtonState {
        peer.isConnected ? .connected : .disconnected
    }

    @ViewBuilder
    private var instrument: some View {
        switch viewModel.mode {
        case .chord:
            // 모드 A/C — 넥으로 짚는다. 단독이면 개별 발음(SPEC §4) + 재생 시 자동 스트럼.
            // 연결되면 무음+진동으로 바뀌고, 운지는 상대(iPad)로 전송돼 거기서 소리가 난다.
            NeckScreen(
                viewModel: chordMode.neck,
                onFingeringChanged: { peer.sendFingering($0) }
            )
                .ignoresSafeArea()
                .onAppear {
                    chordMode.start()
                    chordMode.setConnected(peer.isConnected)
                }
                .onDisappear {
                    chordMode.end()
                    viewModel.isPlaying = false
                }
        case .strum:
            // 스트럼 — 단독(모드 B)이거나 연결됨(모드 C). 연결되면 상대(iPhone)가 짚은 운지로 소리 난다.
            // 그리고 내가 튕길 때마다 그 세기를 상대(iPhone)로 보내 거기서 진동이 나게 한다.
            GuitarStrumView(viewModel: strumViewModel)
                .ignoresSafeArea()
                .onAppear { strumViewModel.updateFingering(peer.receivedFingering.frets) }
                .onChange(of: peer.receivedFingering) { _, fingering in
                    strumViewModel.updateFingering(fingering.frets)
                }
                .onReceive(strumViewModel.strumPerformed) { velocity in
                    peer.sendStrumHaptic(velocity: velocity)
                }
        }
    }
}
