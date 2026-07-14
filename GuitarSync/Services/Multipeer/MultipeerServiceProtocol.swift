import Foundation

protocol MultipeerServiceProtocol: AnyObject {
    var discoveredPeers: [String] { get }
    var connectedPeers: [String] { get }
    var onDiscoveredPeersChanged: (([String]) -> Void)? { get set }
    var onConnectedPeersChanged: (([String]) -> Void)? { get set }
    var onConnectionStateChanged: ((PeerConnectionState) -> Void)? { get set }
    var onMessageReceived: ((PeerMessage, String) -> Void)? { get set }
    var onLog: ((String) -> Void)? { get set }

    func startAdvertising()
    func stopAdvertising()
    func startBrowsing()
    func stopBrowsing()
    func invitePeer(named name: String)
    func send(_ message: PeerMessage)
}
