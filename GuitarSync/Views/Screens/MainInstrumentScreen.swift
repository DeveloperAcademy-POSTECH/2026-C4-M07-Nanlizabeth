import SwiftUI

struct MainInstrumentScreen: View {
    @ObservedObject var viewModel: ScreenshotPrototypeViewModel

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
        }
    }

    @ViewBuilder
    private var instrument: some View {
        switch viewModel.mode {
        case .chord:
            ScreenshotFretboardView(
                selectedFingerNumber: viewModel.selectedFingerNumber,
                onFingerTap: viewModel.selectFingerNumber(_:)
            )
                .ignoresSafeArea()
        case .strum:
            ScreenshotSoundHoleView(receivedFingerNumber: viewModel.receivedFingerNumber)
                .ignoresSafeArea()
        }
    }
}
