struct PeerMessage: Codable, Equatable {
    enum MessageType: String, Codable {
        case selectedChord
        case strum
        case ping
        case syncRequest
        case syncState
        case fingerNumber
        case fingering
        /// 연결 직후 디바이스 종류와 초대를 보낸 쪽인지 교환해 코드/스트로크 역할을 확정한다.
        case connectionIdentity
        /// 코드 담당이 고른 곡 제목. 수신한 스트로크 담당도 같은 드릴 화면을 연다.
        case songSelection
        /// 스트로크 담당이 완료한 곡의 전역 스트로크 스텝.
        case songProgress
        /// iPad가 튕겼다 → iPhone이 그 세기로 진동. (모드 C 햅틱, velocity는 `number`에)
        case strumHaptic
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

    static func connectionIdentity(deviceType: DeviceType, didSelectPeer: Bool) -> PeerMessage {
        PeerMessage(
            type: .connectionIdentity,
            chord: nil,
            direction: nil,
            text: deviceType.rawValue,
            number: didSelectPeer ? 1 : 0,
            frets: nil
        )
    }

    static func songSelection(title: String) -> PeerMessage {
        PeerMessage(type: .songSelection, chord: nil, direction: nil, text: title, number: nil, frets: nil)
    }

    static func songProgress(step: Int) -> PeerMessage {
        PeerMessage(type: .songProgress, chord: nil, direction: nil, text: nil, number: step, frets: nil)
    }

    /// iPad → iPhone 진동 신호. 세기(0~127)를 `number`에 담는다.
    static func strumHaptic(velocity: UInt8) -> PeerMessage {
        PeerMessage(type: .strumHaptic, chord: nil, direction: nil, text: nil, number: Int(velocity), frets: nil)
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
        case .connectionIdentity:
            return "connectionIdentity device=\(text ?? "-") selector=\(number == 1)"
        case .songSelection:
            return "songSelection \(text ?? "-")"
        case .songProgress:
            return "songProgress \(number.map(String.init) ?? "-")"
        case .strumHaptic:
            return "strumHaptic \(number.map(String.init) ?? "-")"
        }
    }
}
