import Combine
import Foundation

/// 연결 화면 2개(가이드·기기 찾기)가 함께 보는 상태. (ARCHITECTURE §3.8 · ROADMAP U7)
///
/// 화면은 **`ConnectionFlowState`만 보고 그린다** — Multipeer 내부 사정을 알 필요가 없다.
@MainActor
final class PeerConnectViewModel: ObservableObject {
    @Published private(set) var flowState: ConnectionFlowState = .idle
    @Published private(set) var discoveredPeers: [String] = []
    /// 가이드에서 지금 보고 있는 단계.
    @Published var guideStep: Int = 0

    /// 이 기기가 맡는 손. 협상 없이 기기 종류로 정해진다.
    let role: PeerHandRole

    private let service: MultipeerServiceProtocol
    private let guideStore: PeerGuideStoreProtocol

    init(
        deviceType: DeviceType = DeviceInfoProvider.currentDeviceType,
        service: MultipeerServiceProtocol? = nil,
        guideStore: PeerGuideStoreProtocol? = nil
    ) {
        self.role = PeerRolePolicy.role(for: deviceType)
        self.service = service ?? Self.defaultService()
        self.guideStore = guideStore ?? PeerGuideStore()
        bind()
    }

    private static func defaultService() -> MultipeerServiceProtocol {
        #if DEBUG
        // 시뮬레이터엔 붙을 상대가 없어 목록·연결됨 상태를 볼 수 없다.
        // 실행 인자 `-mockPeers YES`를 주면 가짜 기기가 나타나 화면 개발·검증이 가능하다.
        if UserDefaults.standard.bool(forKey: "mockPeers") {
            return MockMultipeerService()
        }
        #endif
        return MultipeerService()
    }

    /// 상대 기기가 맡는 손 (안내 문구용).
    var partnerRole: PeerHandRole {
        role == .fingering ? .strumming : .fingering
    }

    var isConnected: Bool { flowState.isConnected }

    /// 가이드를 이미 봤는가 — 연결 버튼이 어디로 갈지 정한다.
    var shouldShowGuide: Bool { !guideStore.hasSeenGuide }

    // MARK: - 가이드

    var guideSteps: [PeerGuideStep] { PeerGuideStep.all(myRole: role, partnerRole: partnerRole) }

    var isLastGuideStep: Bool { guideStep >= guideSteps.count - 1 }

    func advanceGuide() {
        guard !isLastGuideStep else { return }
        guideStep += 1
    }

    /// 가이드를 끝내거나 건너뛴다. **스킵도 "봤음"으로 친다** (SPEC §7).
    func finishGuide() {
        guideStore.markGuideSeen()
        guideStep = 0
    }

    // MARK: - 탐색·연결

    func startBrowsing() {
        flowState = .browsing
        service.startAdvertising()
        service.startBrowsing()
    }

    func invite(_ peerName: String) {
        flowState = .inviting(peerName: peerName)
        service.invitePeer(named: peerName)
    }

    func stop() {
        service.stopBrowsing()
        service.stopAdvertising()
        flowState = .idle
        discoveredPeers = []
    }

    private func bind() {
        service.onDiscoveredPeersChanged = { [weak self] peers in
            self?.discoveredPeers = peers
        }
        service.onConnectedPeersChanged = { [weak self] peers in
            guard let self else { return }
            if let first = peers.first {
                self.flowState = .connected(peerName: first)
            } else if self.flowState.isConnected {
                self.flowState = .disconnected(reason: nil)
            }
        }
        service.onConnectionStateChanged = { [weak self] state in
            guard let self else { return }
            if case .failed(let message) = state {
                self.flowState = .failed(message: message)
            }
        }
    }
}

/// 가이드 한 단계.
struct PeerGuideStep: Identifiable, Equatable {
    let id: Int
    let title: String
    let body: String
    /// 시스템 권한 팝업을 예고하는 단계인가 — 화면에서 강조 표시한다.
    var warnsPermission: Bool = false

    /// SPEC 플로우 3 기준 가이드 문구.
    ///
    /// - Note: HI-FI 디자인이 없어 **문구·구성 모두 초안**입니다. 디자이너 확정 시 이 배열만 고치면 됩니다.
    static func all(myRole: PeerHandRole, partnerRole: PeerHandRole) -> [PeerGuideStep] {
        [
            PeerGuideStep(
                id: 0,
                title: "두 기기가 한 대의 기타가 됩니다",
                body: "이 기기는 \(myRole.displayName)을 맡습니다.\n상대 기기가 \(partnerRole.displayName)을 맡아요."
            ),
            PeerGuideStep(
                id: 1,
                title: "두 기기 모두 이 화면을 열어주세요",
                body: "같은 Wi-Fi에 있으면 가장 잘 찾습니다.\nWi-Fi가 없어도 블루투스로 연결됩니다."
            ),
            PeerGuideStep(
                id: 2,
                title: "허용 팝업이 뜨면 눌러주세요",
                body: "처음 연결할 때 iOS가 '로컬 네트워크' 허용을 묻습니다.\n"
                    + "이 팝업은 화면과 방향이 다르게 보일 수 있어요 — 기기를 세워서 확인하세요.",
                warnsPermission: true
            ),
        ]
    }
}

// MARK: - Mock

/// 실제 통신 없이 화면만 개발할 때 쓰는 가짜 Multipeer. (ARCHITECTURE §4.1)
///
/// `simulateDiscovery()`로 가짜 기기를 등장시키고, 초대하면 잠시 뒤 연결된 척한다.
@MainActor
final class MockMultipeerService: MultipeerServiceProtocol {
    var discoveredPeers: [String] = []
    var connectedPeers: [String] = []

    var onDiscoveredPeersChanged: (([String]) -> Void)?
    var onConnectedPeersChanged: (([String]) -> Void)?
    var onConnectionStateChanged: ((PeerConnectionState) -> Void)?
    var onMessageReceived: ((PeerMessage, String) -> Void)?
    var onLog: ((String) -> Void)?

    /// 초대 후 연결되기까지 걸리는 척하는 시간.
    var connectDelay: TimeInterval = 0.8

    func startAdvertising() {}
    func stopAdvertising() {}

    func startBrowsing() {
        // 잠시 뒤 가짜 기기가 나타난 것처럼.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.simulateDiscovery(["민서의 iPad", "지훈의 iPhone"])
        }
    }

    func stopBrowsing() {
        discoveredPeers = []
        onDiscoveredPeersChanged?(discoveredPeers)
    }

    func invitePeer(named name: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + connectDelay) { [weak self] in
            guard let self else { return }
            self.connectedPeers = [name]
            self.onConnectedPeersChanged?(self.connectedPeers)
        }
    }

    func send(_ message: PeerMessage) {}

    func simulateDiscovery(_ peers: [String]) {
        discoveredPeers = peers
        onDiscoveredPeersChanged?(peers)
    }
}
