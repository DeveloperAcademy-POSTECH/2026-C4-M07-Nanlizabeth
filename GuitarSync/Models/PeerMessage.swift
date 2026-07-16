struct PeerMessage: Codable, Equatable {
    enum MessageType: String, Codable {
        case selectedChord
        case strum
        case ping
        case syncRequest
        case syncState
        case fingerNumber
        case fingering
    }

    let type: MessageType
    let chord: GuitarChord?
    let direction: StrumDirection?
    let text: String?
    let number: Int?
    let frets: [Int]?

    static func selectedChord(_ chord: GuitarChord) -> PeerMessage {
        PeerMessage(type: .selectedChord, chord: chord, direction: nil, text: nil, number: nil, frets: nil)
    }

    static func strum(_ direction: StrumDirection) -> PeerMessage {
        PeerMessage(type: .strum, chord: nil, direction: direction, text: nil, number: nil, frets: nil)
    }

    static func ping(_ text: String) -> PeerMessage {
        PeerMessage(type: .ping, chord: nil, direction: nil, text: text, number: nil, frets: nil)
    }

    static var syncRequest: PeerMessage {
        PeerMessage(type: .syncRequest, chord: nil, direction: nil, text: nil, number: nil, frets: nil)
    }

    static func syncState(chord: GuitarChord?) -> PeerMessage {
        PeerMessage(type: .syncState, chord: chord, direction: nil, text: nil, number: nil, frets: nil)
    }

    static func fingerNumber(_ number: Int) -> PeerMessage {
        PeerMessage(type: .fingerNumber, chord: nil, direction: nil, text: nil, number: number, frets: nil)
    }

    static func fingering(_ frets: [Int], chord: GuitarChord? = nil) -> PeerMessage {
        PeerMessage(type: .fingering, chord: chord, direction: nil, text: nil, number: nil, frets: frets)
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
        case .fingering:
            return "fingering \(chord?.rawValue ?? "-") \(frets?.map(String.init).joined(separator: ",") ?? "-")"
        }
    }
}
