/// 코드 하나의 **이름표**. (ARCHITECTURE §3.3)
///
/// 이름이 곧 정체성이다 — `GuitarChord("Am")`은 어디서 만들어도 같은 코드다.
/// **운지 데이터는 여기 없다.** `ChordCatalog`가 갖고 있고, 실제 값은
/// `Content/ChordCatalogData.swift`에 표로 들어 있다.
///
/// enum이 아니라 struct인 이유: 코드를 추가할 때 **데이터 파일 한 곳만** 고치면 되게 하려고.
/// (enum이면 케이스 추가 + 데이터 추가로 두 군데를 고쳐야 한다 — 리서치 담당에게 부담)
///
/// ```swift
/// let chord = GuitarChord("Cmaj7")
/// let frets = chord.fingering          // ChordCatalog.shared를 거쳐 조회된다
/// ```
struct GuitarChord: RawRepresentable, Hashable, Identifiable, Codable, CustomStringConvertible {
    /// 화면에 그대로 표시되는 이름 ("C", "Am", "Cmaj7").
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var id: String { rawValue }
    var name: String { rawValue }
    var description: String { rawValue }
}

extension GuitarChord {
    /// 저장·전송 형식은 **문자열 하나**다 (`"Am"`).
    ///
    /// 기존 enum일 때의 인코딩과 완전히 동일하므로, 이미 저장된 커스텀 진행 JSON이나
    /// 멀티피어 메시지(`PeerMessage`)와 호환이 깨지지 않는다.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension GuitarChord: ExpressibleByStringLiteral {
    /// `let chord: GuitarChord = "Am"` 처럼 쓸 수 있게. 데이터 표를 짧게 적기 위한 편의.
    init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

// MARK: - 자주 쓰는 코드 바로가기
//
// 코드에서 `GuitarChord.c`처럼 쓰기 위한 이름표일 뿐, 운지 데이터와는 무관하다.
// 새 코드를 추가할 때 여기에 꼭 넣을 필요는 없다 — `Content/ChordCatalogData.swift`만 채우면
// `ChordCatalog.shared.allChords`에 자동으로 들어온다.

extension GuitarChord {
    static let c: GuitarChord = "C"
    static let d: GuitarChord = "D"
    static let e: GuitarChord = "E"
    static let g: GuitarChord = "G"
    static let a: GuitarChord = "A"
    static let am: GuitarChord = "Am"
    static let em: GuitarChord = "Em"
}
