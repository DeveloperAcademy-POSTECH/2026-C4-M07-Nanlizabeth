import SwiftUI

struct MainInstrumentScreen: View {
    @ObservedObject var viewModel: ScreenshotPrototypeViewModel
    @StateObject private var strumViewModel = GuitarStrumViewModel()

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
            ScreenshotFretboardView(
                selectedChord: viewModel.selectedFingeringChord,
                onChordTap: viewModel.selectFingeringChord(_:)
            )
                .ignoresSafeArea()
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
