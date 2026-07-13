import Combine
import Foundation

final class AppState: ObservableObject {
    @Published var deviceType: DeviceType
    @Published var deviceRole: DeviceRole
    @Published var selectedChord: GuitarChord?
    @Published var receivedChord: GuitarChord?
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
        }
    }
}
