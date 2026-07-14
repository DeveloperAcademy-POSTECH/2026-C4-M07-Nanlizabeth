import Combine
import Foundation

final class ScreenshotPrototypeViewModel: ObservableObject {
    private let multipeerService: MultipeerServiceProtocol

    @Published var mode: PrototypeMode = .chord
    @Published var screen: PrototypeScreen = .main
    @Published var isPlaying = false
    @Published var bpm: Double = 70
    @Published var showBPM = false
    @Published var selectedChordRoot = "C"
    @Published var isControlBarExpanded = true
    @Published var peerButtonState: PrototypePeerButtonState = .disconnected
    @Published var selectedFingerNumber: Int?
    @Published var receivedFingerNumber: Int?

    init(multipeerService: MultipeerServiceProtocol = MultipeerService()) {
        self.multipeerService = multipeerService
        self.multipeerService.onDiscoveredPeersChanged = { [weak self] peers in
            guard let self, self.peerButtonState == .connecting, let peerName = peers.first else { return }
            self.multipeerService.invitePeer(named: peerName)
        }
        self.multipeerService.onConnectionStateChanged = { [weak self] state in
            self?.peerButtonState = state.isConnected ? .connected : self?.peerButtonState ?? .disconnected
        }
        self.multipeerService.onConnectedPeersChanged = { [weak self] peers in
            self?.peerButtonState = peers.isEmpty ? .connecting : .connected
        }
        self.multipeerService.onMessageReceived = { [weak self] message, _ in
            guard message.type == .fingerNumber else { return }
            self?.receivedFingerNumber = message.number
        }
    }

    var actionTitle: String {
        mode == .chord ? "S" : "C"
    }

    func toggleMode(_ nextMode: PrototypeMode) {
        mode = nextMode
        showBPM = false
    }

    func togglePlayback() {
        isPlaying.toggle()
    }

    func toggleBPM() {
        showBPM.toggle()
    }

    func toggleControls() {
        isControlBarExpanded.toggle()
        if !isControlBarExpanded {
            showBPM = false
        }
    }

    func togglePeerConnection() {
        if peerButtonState != .disconnected {
            multipeerService.stopBrowsing()
            multipeerService.stopAdvertising()
            peerButtonState = .disconnected
        } else {
            multipeerService.startAdvertising()
            multipeerService.startBrowsing()
            peerButtonState = .connecting
        }
    }

    func openActionScreen() {
        showBPM = false
        screen = mode == .chord ? .strumSelect : .chordProgression
    }

    func backToMain() {
        screen = .main
    }

    func openStrumCreate() {
        screen = .strumCreate
    }

    func backToStrumSelect() {
        screen = .strumSelect
    }

    func selectFingerNumber(_ number: Int) {
        selectedFingerNumber = number
        multipeerService.send(.fingerNumber(number))
    }
}
