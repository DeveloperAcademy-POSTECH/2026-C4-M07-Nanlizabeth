/// 왼손이 지금 짚고 있는 상태 — 6개 줄 각각 몇 프렛인가.
///
/// **규약 (ARCHITECTURE §5):** `frets[0]` = 6번줄(저음 E) … `frets[5]` = 1번줄(고음 E).
/// 값은 `-1`=뮤트 · `0`=개방현 · `1~`=프렛 번호.
struct GuitarFingering: Equatable, Hashable, Codable {
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

    /// 이 줄을 소리 낼 수 있는가 (뮤트가 아닌가).
    func isAudible(stringIndex: Int) -> Bool {
        guard let fret = fret(for: stringIndex) else { return false }
        return fret >= 0
    }

    /// 아무 줄도 울리지 않는 상태인가 (전부 뮤트).
    var isSilent: Bool {
        frets.allSatisfy { $0 < 0 }
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
    /// 이 코드의 운지. **실제 데이터는 `Content/ChordCatalogData.swift`에 있다.**
    ///
    /// 카탈로그에 없는 코드면 개방현을 돌려준다 (소리는 나되 틀린 음이 아님).
    /// 특정 카탈로그를 지정해 조회하려면 `ChordCatalog.fingering(for:)`를 직접 쓴다.
    var fingering: GuitarFingering {
        ChordCatalog.shared.fingering(for: self) ?? .open
    }

    /// 이 코드를 짚는 손가락 번호(줄마다 하나). `0`=안 짚음 · `1`검지 · `2`중지 · `3`약지 · `4`새끼.
    /// 데이터가 없으면 빈 배열. **실제 데이터는 `Content/ChordCatalogData.swift`에 있다.**
    var fingers: [Int] {
        ChordCatalog.shared.fingers(for: self)
    }
}
