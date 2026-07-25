import Combine
import Foundation

final class AppState: ObservableObject {
    @Published var deviceType: DeviceType
    @Published var deviceRole: DeviceRole
    @Published var selectedChord: GuitarChord?
    @Published var receivedChord: GuitarChord?
    @Published var receivedFrets: [Int] = Array(repeating: 0, count: GuitarFingering.stringCount)
    @Published var lastStrumDirection: StrumDirection?
    @Published var connectionState: PeerConnectionState = .idle
    @Published var discoveredPeerNames: [String] = []
    @Published var connectedPeerNames: [String] = []
    @Published var logs: [AppLogItem] = []

    init(
        deviceType: DeviceType = DeviceInfoProvider.currentDeviceType,
        deviceRole: DeviceRole? = nil
    ) {
        self.deviceType = deviceType
        self.deviceRole = deviceRole ?? DeviceInfoProvider.defaultRole(for: deviceType)
        addLog("App", "Started as \(self.deviceType.displayName) / \(self.deviceRole.displayName)")
    }

    var activeChord: GuitarChord? {
        receivedChord ?? selectedChord
    }

    func addLog(_ category: String, _ message: String) {
        logs.insert(Logger.item(category, message), at: 0)
        if logs.count > 80 {
            logs.removeLast(logs.count - 80)
        }
    }

    func clearLogs() {
        logs.removeAll()
        addLog("Debug", "Logs cleared")
    }

    func applyReceivedMessage(_ message: PeerMessage, from peerName: String) {
        addLog("RX \(peerName)", message.logText)
        switch message.type {
        case .selectedChord:
            receivedChord = message.chord
        case .strum:
            lastStrumDirection = message.direction
        case .ping:
            break
        case .syncRequest:
            break
        case .syncState:
            receivedChord = message.chord
        case .fingerNumber:
            break
        case .fingering:
            if let frets = message.frets {
                receivedFrets = GuitarFingering(frets: frets).frets
            }
            receivedChord = message.chord
        case .connectionIdentity:
            // 연결 역할 협상은 PeerConnectViewModel이 처리한다.
            break
        case .songSelection, .songProgress:
            // 연결 곡 동기화는 PeerConnectViewModel이 처리한다.
            break
        case .strumHaptic:
            // 진동 신호 — 이 레거시 상태 저장소에서는 다루지 않는다 (PeerConnectViewModel이 처리).
            break
        }
    }
}
