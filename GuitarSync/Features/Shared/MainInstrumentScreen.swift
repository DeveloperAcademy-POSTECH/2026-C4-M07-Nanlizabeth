import SwiftUI

struct MainInstrumentScreen: View {
    @ObservedObject var viewModel: ScreenshotPrototypeViewModel
    @StateObject private var strumViewModel = GuitarStrumViewModel()
    @StateObject private var neckViewModel = NeckViewModel()

    // ⚠️ **알려진 비용: 이 셸에서는 오디오 엔진이 두 벌 만들어진다.**
    //
    // 넥과 스트럼이 각자 뷰모델을 들고 있고 뷰모델마다 엔진을 만들기 때문이다.
    // 화면은 한 번에 하나만 보이므로 소리가 겹치지는 않지만, 샘플러 12개 + 사운드폰트 2회 로드라
    // **메모리를 두 배로 쓴다.** A3(엔진 A/B 실측)가 이 상태에서 잰 메모리 값을 그대로 믿으면 안 된다.
    //
    // 제대로 된 자리는 세션 코디네이터(ARCHITECTURE §3.7)다 — 왼손·오른손 소스를 조립하는 쪽이
    // 엔진 하나를 소유하고 양쪽에 나눠주는 구조. **태스크 L5에서 정리된다.**
    // 여기서 미리 고치지 않는 이유: 이 셸 자체가 U2·U3 완성과 함께 사라질 코드라
    // 지금 손대면 버릴 코드에 설계를 얹는 셈이 된다.

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
                onPeer: viewModel.togglePeerConnection,
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
    }

    @ViewBuilder
    private var instrument: some View {
        switch viewModel.mode {
        case .chord:
            // U2 — 진짜 기타넥. 멀티터치로 짚으면 그 자리에서 소리가 난다 (SPEC §4).
            // 운지가 바뀔 때마다 상대 기기로도 보낸다 (모드 C의 왼손 역할).
            NeckScreen(
                viewModel: neckViewModel,
                onFingeringChanged: viewModel.sendFingering
            )
                .ignoresSafeArea()
                .onAppear { neckViewModel.startAudio() }
                .onDisappear { neckViewModel.stopAudio() }
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
