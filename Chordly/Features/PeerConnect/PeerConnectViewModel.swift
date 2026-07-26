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

    /// 연결된 상대가 방금 보내온 운지. **iPad(스트로크 쪽)가 이걸로 소리를 낸다.** (모드 C)
    @Published private(set) var receivedFingering: GuitarFingering = .open
    /// 연결된 상대 이름 (피드백 표시용).
    @Published private(set) var connectedPeerName: String?
    @Published private(set) var localDisplayName: String = PeerDisplayNameStore.currentName

    /// 상대(iPad)가 튕길 때마다 오른다 — 튜토리얼이 "짝이 실제로 연주했다"를 감지하는 신호.
    @Published private(set) var remoteStrumTick: Int = 0
    /// 수신 측이 아직 수락하거나 거절하지 않은 연결 요청.
    @Published private(set) var pendingInvitationPeerName: String?
    /// 연결 합주에서 양쪽이 함께 보고 있는 곡과 진행 스텝.
    @Published private(set) var sharedSongTitle: String?
    @Published private(set) var sharedSongStep: Int = 0
    @Published private(set) var sharedSongSelectionTick: Int = 0

    /// 연결 전에는 디바이스 기본 역할, 연결 후에는 초대 방향과 iPad 우선 규칙으로 확정된 역할.
    @Published private(set) var role: PeerHandRole

    /// 연결 전에는 양쪽 모두 검색할 수 있고, 연결 후에는 실제로 상대를 선택한 쪽만 주체다.
    var isInitiator: Bool { !isConnected || didSelectPeer }
    var isConnectionRequester: Bool { isConnected && didSelectPeer }

    /// 마지막으로 보낸 운지 — 같은 값을 반복 전송하지 않으려고 기억한다.
    private var lastSentFingering: GuitarFingering?

    /// 상대(iPad)가 튕겼다는 신호를 받았을 때 여기서 진동을 낸다. (모드 C의 iPhone이 손맛을 느낀다)
    private let strumHaptics = DecayHapticPlayer()
    /// 짧은 창 안의 여러 튕김을 하나로 합쳐 보내려는 상태.
    private var pendingStrumVelocity: UInt8 = 0
    private var strumSendTask: Task<Void, Never>?

    private var service: MultipeerServiceProtocol
    private let guideStore: PeerGuideStoreProtocol
    private let localDeviceType: DeviceType
    private var didSelectPeer = false

    init(
        deviceType: DeviceType = DeviceInfoProvider.currentDeviceType,
        service: MultipeerServiceProtocol? = nil,
        guideStore: PeerGuideStoreProtocol? = nil
    ) {
        self.localDeviceType = deviceType
        self.role = PeerRolePolicy.role(for: deviceType)
        self.service = service ?? Self.defaultService(displayName: PeerDisplayNameStore.currentName)
        self.guideStore = guideStore ?? PeerGuideStore()
        bind()
    }

    private static func defaultService(displayName: String) -> MultipeerServiceProtocol {
        #if DEBUG
        // 시뮬레이터엔 붙을 상대가 없어 목록·연결됨 상태를 볼 수 없다.
        // 실행 인자 `-mockPeers YES`를 주면 가짜 기기가 나타나 화면 개발·검증이 가능하다.
        if UserDefaults.standard.bool(forKey: "mockPeers") {
            return MockMultipeerService()
        }
        #endif
        return MultipeerService(displayName: displayName)
    }

    /// 상대 기기가 맡는 손 (안내 문구용).
    var partnerRole: PeerHandRole {
        role == .fingering ? .strumming : .fingering
    }

    var isConnected: Bool { flowState.isConnected }
    var hasCustomDisplayName: Bool { PeerDisplayNameStore.savedName != nil }

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

    /// 저장된 이름으로 멀티피어 세션을 새로 만들어 다른 기기의 검색 목록에 그대로 노출한다.
    @discardableResult
    func setDisplayName(_ name: String) -> Bool {
        guard let saved = PeerDisplayNameStore.save(name) else { return false }
        service.disconnect()
        service = Self.defaultService(displayName: saved)
        localDisplayName = saved
        flowState = .idle
        discoveredPeers = []
        connectedPeerName = nil
        bind()
        return true
    }

    /// 연결을 시작한다. iPhone과 iPad 모두 주변 디바이스를 찾고 동시에 자신을 노출한다.
    func startBrowsing() {
        didSelectPeer = false
        flowState = .browsing
        service.startAdvertising()
        service.startBrowsing()
    }

    func invite(_ peerName: String) {
        didSelectPeer = true
        flowState = .inviting(peerName: peerName)
        service.invitePeer(named: peerName)
    }

    func respondToInvitation(accept: Bool) {
        guard pendingInvitationPeerName != nil else { return }
        pendingInvitationPeerName = nil
        didSelectPeer = false
        service.respondToInvitation(accept: accept)
    }

    /// 곡 선택 권한은 연결을 요청해 코드 역할을 맡은 디바이스에만 있다.
    func selectSharedSong(title: String) {
        guard isConnected, role == .fingering else { return }
        sharedSongTitle = title
        sharedSongStep = 0
        sharedSongSelectionTick &+= 1
        service.send(.songSelection(title: title))
    }

    /// 실제 스트로크가 진행된 순서를 코드 담당에게 보낸다.
    func sendSharedSongProgress(step: Int) {
        guard isConnected, role == .strumming else { return }
        sharedSongStep = max(0, step)
        service.send(.songProgress(step: sharedSongStep))
    }

    /// 내 운지를 상대에게 보낸다. **모드 C의 iPhone(짚기 담당).** 같은 운지는 다시 안 보낸다.
    func sendFingering(_ fingering: GuitarFingering) {
        guard isConnected, role == .fingering, fingering != lastSentFingering else { return }
        lastSentFingering = fingering
        service.send(.fingering(fingering.frets))
    }

    /// 내가 튕겼다는 걸 상대(iPhone)에게 알려 **거기서 진동**하게 한다. **모드 C의 iPad(긁기 담당).**
    /// 한 번 긁으면 여러 줄이 몰아치므로 30ms 창에서 가장 센 것 하나로 합쳐 보낸다.
    func sendStrumHaptic(velocity: UInt8) {
        guard isConnected, role == .strumming else { return }
        pendingStrumVelocity = max(pendingStrumVelocity, velocity)
        guard strumSendTask == nil else { return }
        strumSendTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(30))
            guard let self else { return }
            self.service.send(.strumHaptic(velocity: self.pendingStrumVelocity))
            self.pendingStrumVelocity = 0
            self.strumSendTask = nil
        }
    }

    /// 연결을 끊는다. **iPhone(주체)이 부른다.**
    func disconnect() {
        stop()
    }

    func stop() {
        // 세션까지 완전히 끊어 재연결이 깨끗하게 되게 한다.
        service.disconnect()
        flowState = .idle
        discoveredPeers = []
        didSelectPeer = false
        pendingInvitationPeerName = nil
        sharedSongTitle = nil
        sharedSongStep = 0
        role = PeerRolePolicy.role(for: localDeviceType)
    }

    private func bind() {
        service.onDiscoveredPeersChanged = { [weak self] peers in
            self?.discoveredPeers = peers
        }
        service.onInvitationReceived = { [weak self] peerName in
            self?.didSelectPeer = false
            self?.pendingInvitationPeerName = peerName
        }
        service.onConnectedPeersChanged = { [weak self] peers in
            guard let self else { return }
            if let first = peers.first {
                self.connectedPeerName = first
                self.flowState = .connected(peerName: first)
                self.service.send(
                    .connectionIdentity(
                        deviceType: self.localDeviceType,
                        didSelectPeer: self.didSelectPeer
                    )
                )
            } else {
                let wasConnected = self.flowState.isConnected
                self.connectedPeerName = nil
                self.lastSentFingering = nil
                self.receivedFingering = .open
                if wasConnected {
                    self.flowState = .disconnected(reason: nil)
                    self.didSelectPeer = false
                    self.sharedSongTitle = nil
                    self.sharedSongStep = 0
                    self.role = PeerRolePolicy.role(for: self.localDeviceType)
                }
            }
        }
        service.onConnectionStateChanged = { [weak self] state in
            guard let self else { return }
            if case .failed(let message) = state {
                self.flowState = .failed(message: message)
            }
        }
        service.onMessageReceived = { [weak self] message, _ in
            guard let self else { return }
            switch message.type {
            case .connectionIdentity:
                let remoteDeviceType = message.text.flatMap(DeviceType.init(rawValue:)) ?? .unknown
                let remoteDidSelectPeer = message.number == 1
                self.resolveRole(
                    remoteDeviceType: remoteDeviceType,
                    remoteDidSelectPeer: remoteDidSelectPeer
                )
            case .songSelection:
                if self.role == .strumming, let title = message.text {
                    self.sharedSongTitle = title
                    self.sharedSongStep = 0
                    self.sharedSongSelectionTick &+= 1
                }
            case .songProgress:
                if self.role == .fingering, let step = message.number {
                    self.sharedSongStep = max(0, step)
                }
            case .fingering:
                // 상대(iPhone)가 짚은 운지 → iPad가 이걸로 소리 낸다.
                if self.role == .strumming, let frets = message.frets {
                    self.receivedFingering = GuitarFingering(frets: frets)
                }
            case .strumHaptic:
                // 상대(iPad)가 튕겼다 → iPhone이 그 세기로 진동. 손맛이 여기서 난다.
                if self.role == .fingering, let velocity = message.number {
                    self.strumHaptics.pluck(velocity: UInt8(clamping: velocity))
                    self.remoteStrumTick += 1
                }
            default:
                break
            }
        }
    }

    private func resolveRole(
        remoteDeviceType: DeviceType,
        remoteDidSelectPeer: Bool
    ) {
        if localDeviceType == .iPad, remoteDeviceType == .iPhone {
            role = .strumming
            return
        }
        if localDeviceType == .iPhone, remoteDeviceType == .iPad {
            role = .fingering
            return
        }

        if didSelectPeer != remoteDidSelectPeer {
            role = didSelectPeer ? .fingering : .strumming
            return
        }

        // 양쪽이 동시에 눌렀을 때도 서로 반대 역할을 고르도록 이름으로 안정적인 타이브레이크를 둔다.
        let remoteName = connectedPeerName ?? ""
        role = localDisplayName.localizedStandardCompare(remoteName) == .orderedAscending
            ? .fingering
            : .strumming
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
                title: "두 디바이스가 한 대의 기타가 됩니다",
                body: "이 디바이스는 \(myRole.displayName)을 맡습니다.\n상대 디바이스가 \(partnerRole.displayName)을 맡아요."
            ),
            PeerGuideStep(
                id: 1,
                title: "두 디바이스 모두 이 화면을 열어주세요",
                body: "같은 Wi-Fi에 있으면 가장 잘 찾습니다.\nWi-Fi가 없어도 블루투스로 연결됩니다."
            ),
            PeerGuideStep(
                id: 2,
                title: "허용 팝업이 뜨면 눌러주세요",
                body: "처음 연결할 때 iOS가 '로컬 네트워크' 허용을 묻습니다.\n"
                    + "이 팝업은 화면과 방향이 다르게 보일 수 있어요. 디바이스를 세워서 확인하세요.",
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
    var onInvitationReceived: ((String) -> Void)?
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

    func respondToInvitation(accept: Bool) {}

    func disconnect() {
        connectedPeers = []
        discoveredPeers = []
        onConnectedPeersChanged?(connectedPeers)
        onDiscoveredPeersChanged?(discoveredPeers)
        onConnectionStateChanged?(.idle)
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
