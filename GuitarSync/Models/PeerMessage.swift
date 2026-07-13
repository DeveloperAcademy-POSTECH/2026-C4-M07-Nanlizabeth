struct PeerMessage: Codable, Equatable {
    enum MessageType: String, Codable {
        case selectedChord
        case strum
        case ping
        case syncRequest
        case syncState
        case fingerNumber
    }

    let type: MessageType
    let chord: GuitarChord?
    let direction: StrumDirection?
    let text: String?
    let number: Int?

    static func selectedChord(_ chord: GuitarChord) -> PeerMessage {
        PeerMessage(type: .selectedChord, chord: chord, direction: nil, text: nil, number: nil)
    }

    static func strum(_ direction: StrumDirection) -> PeerMessage {
        PeerMessage(type: .strum, chord: nil, direction: direction, text: nil, number: nil)
    }

    static func ping(_ text: String) -> PeerMessage {
        PeerMessage(type: .ping, chord: nil, direction: nil, text: text, number: nil)
    }

    static var syncRequest: PeerMessage {
        PeerMessage(type: .syncRequest, chord: nil, direction: nil, text: nil, number: nil)
    }

    static func syncState(chord: GuitarChord?) -> PeerMessage {
        PeerMessage(type: .syncState, chord: chord, direction: nil, text: nil, number: nil)
    }

    static func fingerNumber(_ number: Int) -> PeerMessage {
        PeerMessage(type: .fingerNumber, chord: nil, direction: nil, text: nil, number: number)
    }

    var logText: String {
        switch type {
        case .selectedChord:
            return "selectedChord \(chord?.rawValue ?? "-")"
        case .strum:
            return "strum \(direction?.displayName ?? "-")"
        case .ping:
            return "ping \(text ?? "-")"
        case .syncRequest:
            return "syncRequest"
        case .syncState:
            return "syncState chord=\(chord?.rawValue ?? "none")"
        case .fingerNumber:
            return "fingerNumber \(number.map(String.init) ?? "-")"
        }
    }
}
