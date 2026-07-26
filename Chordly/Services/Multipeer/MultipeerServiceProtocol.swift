import Foundation

protocol MultipeerServiceProtocol: AnyObject {
    var discoveredPeers: [String] { get }
    var connectedPeers: [String] { get }
    var onDiscoveredPeersChanged: (([String]) -> Void)? { get set }
    var onConnectedPeersChanged: (([String]) -> Void)? { get set }
    var onConnectionStateChanged: ((PeerConnectionState) -> Void)? { get set }
    var onMessageReceived: ((PeerMessage, String) -> Void)? { get set }
    var onInvitationReceived: ((String) -> Void)? { get set }
    var onLog: ((String) -> Void)? { get set }

    func startAdvertising()
    func stopAdvertising()
    func startBrowsing()
    func stopBrowsing()
    func invitePeer(named name: String)
    /// 수신한 연결 요청에 사용자가 직접 응답한다.
    func respondToInvitation(accept: Bool)
    /// 세션을 완전히 끊는다. 재연결이 깨끗하게 되도록 상태를 리셋한다.
    func disconnect()
    func send(_ message: PeerMessage)
}
