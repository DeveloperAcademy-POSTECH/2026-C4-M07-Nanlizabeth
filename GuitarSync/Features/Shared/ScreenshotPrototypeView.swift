import SwiftUI

struct ScreenshotPrototypeView: View {
    @StateObject private var viewModel = ScreenshotPrototypeViewModel()

    var body: some View {
        PortraitLockedLandscapeStage {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.045)
                    .ignoresSafeArea()

                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.screen {
        case .main:
            MainInstrumentScreen(viewModel: viewModel)
        case .strumSelect:
            StrumSelectScreen(
                onBack: viewModel.backToMain,
                onConfirm: viewModel.backToMain
            )
        case .chordProgression:
            ChordProgressionScreen(
                selectedRoot: $viewModel.selectedChordRoot,
                onBack: viewModel.backToMain,
                onConfirm: viewModel.backToMain
            )
        }
    }
}
