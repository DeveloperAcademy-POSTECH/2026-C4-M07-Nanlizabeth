import SwiftUI

struct MainInstrumentScreen: View {
    @ObservedObject var viewModel: ScreenshotPrototypeViewModel
    @StateObject private var strumViewModel = GuitarStrumViewModel()

    /// 모드 A(넥 + 자동 스트럼). 엔진·운지상태를 하나로 공유해 조립한 컨트롤러.
    @StateObject private var chordMode = ChordModeController()

    /// 스트로크 선택(U4)에서 고른 주법. 재생 시 자동 스트럼이 이걸 긁는다.
    var selectedStrumPattern: StrumPattern?

    /// 연결 버튼(🔗)을 눌렀을 때. 기기 찾기 화면으로 이동한다 (AppRootView가 라우팅).
    var onPeerConnect: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topTrailing) {
            instrument

            TopControlBar(
                mode: viewModel.mode,
                isPlaying: viewModel.isPlaying,
                isExpanded: viewModel.isControlBarExpanded,
                peerButtonState: viewModel.peerButtonState,
                actionTitle: viewModel.actionTitle,
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
    }

    /// 고른 주법이 있으면 그걸, 없으면 첫 프리셋을 자동 스트럼에 쓴다 —
    /// 재생을 누르면 무언가는 반드시 들리게.
    private var patternToPlay: StrumPattern {
        selectedStrumPattern ?? StrumPatternLibrary().presets.first ?? .fallback
    }

    @ViewBuilder
    private var instrument: some View {
        switch viewModel.mode {
        case .chord:
            // 모드 A — 넥으로 짚으면 개별 발음(SPEC §4), 재생하면 그 코드를 자동 주법으로 긁는다.
            // 운지가 바뀔 때마다 상대 기기로도 보낸다 (모드 C의 왼손 역할).
            NeckScreen(
                viewModel: chordMode.neck,
                onFingeringChanged: viewModel.sendFingering
            )
                .ignoresSafeArea()
                .onAppear { chordMode.start() }
                .onDisappear {
                    chordMode.end()
                    viewModel.isPlaying = false
                }
        case .strum:
            GuitarStrumView(viewModel: strumViewModel)
                .ignoresSafeArea()
                .onAppear {
                    strumViewModel.updateFingering(viewModel.receivedFrets)
                }
                .onChange(of: viewModel.receivedFrets) { _, frets in
                    strumViewModel.updateFingering(frets)
                }
        }
    }
}
