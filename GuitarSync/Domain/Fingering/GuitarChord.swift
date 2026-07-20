enum GuitarChord: String, CaseIterable, Identifiable, Codable {
    case c = "C"
    case d = "D"
    case e = "E"
    case g = "G"
    case a = "A"
    case am = "Am"
    case em = "Em"

    var id: String { rawValue }
}
