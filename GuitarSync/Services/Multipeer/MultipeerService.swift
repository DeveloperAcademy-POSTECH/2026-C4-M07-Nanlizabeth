import Combine
import Foundation
import MultipeerConnectivity
import UIKit

final class MultipeerService: NSObject, ObservableObject, MultipeerServiceProtocol {
    private let serviceType = "gtrsync-demo"
    private let localPeerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var discoveredPeerIDs: [MCPeerID] = []

    @Published private(set) var discoveredPeers: [String] = []
    @Published private(set) var connectedPeers: [String] = []

    var onDiscoveredPeersChanged: (([String]) -> Void)?
    var onConnectedPeersChanged: (([String]) -> Void)?
    var onConnectionStateChanged: ((PeerConnectionState) -> Void)?
    var onMessageReceived: ((PeerMessage, String) -> Void)?
    var onLog: ((String) -> Void)?

    var localDisplayName: String {
        localPeerID.displayName
    }

    override init() {
        let name = "\(UIDevice.current.name)-\(UUID().uuidString.prefix(4))"
        localPeerID = MCPeerID(displayName: name)
        session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    func startAdvertising() {
        if advertiser == nil {
            advertiser = MCNearbyServiceAdvertiser(peer: localPeerID, discoveryInfo: nil, serviceType: serviceType)
            advertiser?.delegate = self
        }
        advertiser?.startAdvertisingPeer()
        onConnectionStateChanged?(.advertising)
        onLog?("Advertising started")
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        onConnectionStateChanged?(connectedPeers.isEmpty ? .idle : .connected)
        onLog?("Advertising stopped")
    }

    func startBrowsing() {
        if browser == nil {
            browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: serviceType)
            browser?.delegate = self
        }
        browser?.startBrowsingForPeers()
        onConnectionStateChanged?(.browsing)
        onLog?("Browsing started")
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        onConnectionStateChanged?(connectedPeers.isEmpty ? .idle : .connected)
        onLog?("Browsing stopped")
    }

    func invitePeer(named name: String) {
        guard let peerID = discoveredPeerIDs.first(where: { $0.displayName == name }) else {
            onLog?("Invite failed: \(name) not found")
            return
        }
        browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 20)
        onLog?("Invite sent to \(name)")
    }

    func send(_ message: PeerMessage) {
        guard !session.connectedPeers.isEmpty else {
            onLog?("No connected peers for \(message.logText)")
            return
        }

        do {
            let data = try MultipeerMessageCodec.encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            onLog?("Sent \(message.logText)")
        } catch {
            onConnectionStateChanged?(.failed(error.localizedDescription))
            onLog?("Send failed: \(error.localizedDescription)")
        }
    }
}

extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            self.onLog?("Accepted invitation from \(peerID.displayName)")
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        Task { @MainActor in
            self.onConnectionStateChanged?(.failed(error.localizedDescription))
            self.onLog?("Advertise failed: \(error.localizedDescription)")
        }
    }
}

extension MultipeerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            guard peerID.displayName != self.localPeerID.displayName else { return }
            if !self.discoveredPeerIDs.contains(peerID) {
                self.discoveredPeerIDs.append(peerID)
                self.discoveredPeers = self.discoveredPeerIDs.map(\.displayName).sorted()
                self.onDiscoveredPeersChanged?(self.discoveredPeers)
                self.onLog?("Found peer \(peerID.displayName)")
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeerIDs.removeAll { $0 == peerID }
            self.discoveredPeers = self.discoveredPeerIDs.map(\.displayName).sorted()
            self.onDiscoveredPeersChanged?(self.discoveredPeers)
            self.onLog?("Lost peer \(peerID.displayName)")
        }
    }

    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
        Task { @MainActor in
            self.onConnectionStateChanged?(.failed(error.localizedDescription))
            self.onLog?("Browse failed: \(error.localizedDescription)")
        }
    }
}

extension MultipeerService: MCSessionDelegate {
    nonisolated func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        Task { @MainActor in
            self.connectedPeers = session.connectedPeers.map(\.displayName).sorted()
            self.onConnectedPeersChanged?(self.connectedPeers)
            self.onConnectionStateChanged?(self.connectedPeers.isEmpty ? .idle : .connected)
            self.onLog?("\(peerID.displayName) \(state.displayName)")
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        Task { @MainActor in
            do {
                let message = try MultipeerMessageCodec.decode(data)
                self.onMessageReceived?(message, peerID.displayName)
            } catch {
                self.onLog?("Decode failed from \(peerID.displayName): \(error.localizedDescription)")
            }
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

private extension MCSessionState {
    var displayName: String {
        switch self {
        case .notConnected:
            return "not connected"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        @unknown default:
            return "unknown"
        }
    }
}
