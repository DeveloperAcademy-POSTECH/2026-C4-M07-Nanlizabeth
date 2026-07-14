enum DeviceRole: String {
    case chordAndStrum
    case strumOnly

    var displayName: String {
        switch self {
        case .chordAndStrum: return "Chord + Strum"
        case .strumOnly: return "Strum Only"
        }
    }
}
