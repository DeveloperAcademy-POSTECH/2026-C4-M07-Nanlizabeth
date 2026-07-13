enum StrumDirection: String, Codable {
    case up
    case down

    var displayName: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        }
    }
}
