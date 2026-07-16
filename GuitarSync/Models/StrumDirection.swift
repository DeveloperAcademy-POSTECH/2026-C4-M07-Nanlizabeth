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

enum RawStrumDirection: String, Codable {
    case forward
    case backward
}

struct StrumDirectionMapping: Equatable {
    var forwardIsDown: Bool

    init(forwardIsDown: Bool = true) {
        self.forwardIsDown = forwardIsDown
    }

    func direction(for rawDirection: RawStrumDirection) -> StrumDirection {
        switch (rawDirection, forwardIsDown) {
        case (.forward, true), (.backward, false):
            return .down
        case (.forward, false), (.backward, true):
            return .up
        }
    }
}
