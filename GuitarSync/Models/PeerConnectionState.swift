enum PeerConnectionState: Equatable {
    case idle
    case advertising
    case browsing
    case connected
    case failed(String)

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .advertising: return "Advertising"
        case .browsing: return "Browsing"
        case .connected: return "Connected"
        case .failed(let message): return "Failed: \(message)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
