struct GuitarFingering: Equatable {
    static let stringCount = 6

    var frets: [Int]

    init(frets: [Int] = Array(repeating: 0, count: stringCount)) {
        if frets.count == Self.stringCount {
            self.frets = frets
        } else {
            self.frets = Array(frets.prefix(Self.stringCount))
            while self.frets.count < Self.stringCount {
                self.frets.append(0)
            }
        }
    }

    func fret(for stringIndex: Int) -> Int? {
        guard frets.indices.contains(stringIndex) else { return nil }
        return frets[stringIndex]
    }
}

extension GuitarFingering {
    static let open = GuitarFingering()
    static let cMajor = GuitarFingering(frets: [-1, 3, 2, 0, 1, 0])
    static let gMajor = GuitarFingering(frets: [3, 2, 0, 0, 0, 3])
    static let dMajor = GuitarFingering(frets: [-1, -1, 0, 2, 3, 2])
    static let aMajor = GuitarFingering(frets: [-1, 0, 2, 2, 2, 0])
    static let aMinor = GuitarFingering(frets: [-1, 0, 2, 2, 1, 0])
    static let eMajor = GuitarFingering(frets: [0, 2, 2, 1, 0, 0])
    static let eMinor = GuitarFingering(frets: [0, 2, 2, 0, 0, 0])
}

extension GuitarChord {
    var fingering: GuitarFingering {
        switch self {
        case .c:
            return .cMajor
        case .d:
            return .dMajor
        case .e:
            return .eMajor
        case .g:
            return .gMajor
        case .a:
            return .aMajor
        case .am:
            return .aMinor
        case .em:
            return .eMinor
        }
    }
}
