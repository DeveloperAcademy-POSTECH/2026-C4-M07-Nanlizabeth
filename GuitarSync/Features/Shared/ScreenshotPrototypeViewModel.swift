import Combine
import Foundation

final class ScreenshotPrototypeViewModel: ObservableObject {
    private let multipeerService: MultipeerServiceProtocol

    @Published var mode: PrototypeMode = .chord
    @Published var screen: PrototypeScreen = .main
    @Published var isPlaying = false
    @Published var bpm: Double = 70
    @Published var showBPM = false
    @Published var isControlBarExpanded = true
    @Published var peerButtonState: PrototypePeerButtonState = .disconnected
    /// 상대(iPad→iPhone 등)가 보낸 운지·손가락 번호. 스트럼 사운드홀 표시가 읽는다.
    @Published var receivedFingerNumber: Int?
    @Published var receivedFrets: [Int] = Array(repeating: 0, count: GuitarFingering.stringCount)

    /// 마지막으로 상대에게 보낸 운지. 같은 값을 반복 전송하지 않으려고 들고 있다.
    private var lastSentFingering: GuitarFingering?

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
            switch message.type {
            case .fingerNumber:
                self?.receivedFingerNumber = message.number
            case .fingering:
                if let frets = message.frets {
                    self?.receivedFrets = GuitarFingering(frets: frets).frets
                }
            default:
                return
            }
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

    /// 넥 화면(U2)의 실시간 운지를 상대 기기로 보낸다.
    ///
    /// **같은 운지는 다시 보내지 않는다** — 손가락을 얹고 있는 동안 메시지가 쏟아지면
    /// 연결이 버티지 못한다. 본격적인 전송 정책(주기·묶음)은 N1에서 정한다.
    func sendFingering(_ fingering: GuitarFingering) {
        guard fingering != lastSentFingering else { return }

        lastSentFingering = fingering
        receivedFrets = fingering.frets
        multipeerService.send(.fingering(fingering.frets))
    }
}
