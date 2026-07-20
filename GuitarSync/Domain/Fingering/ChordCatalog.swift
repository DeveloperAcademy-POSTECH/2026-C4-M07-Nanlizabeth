/// 코드 사전의 한 줄. "이 코드는 이렇게 짚는다"
///
/// 리서치 담당이 채우는 단위다 (`Content/ChordCatalogData.swift`).
struct ChordEntry: Equatable, Identifiable {
    /// 코드 이름표.
    let chord: GuitarChord
    /// 근음 — 선택 화면에서 근음별로 묶어 보여줄 때 쓴다 ("C", "A#", "Bb").
    let root: String
    /// 운지. `-1`=뮤트 · `0`=개방현 · `1~`=프렛 (ARCHITECTURE §5 규약)
    let fingering: GuitarFingering

    var id: String { chord.id }

    init(chord: GuitarChord, root: String, fingering: GuitarFingering) {
        self.chord = chord
        self.root = root
        self.fingering = fingering
    }

    /// 데이터 표를 짧게 적기 위한 편의 생성자.
    ///
    /// ```swift
    /// ChordEntry("Am", root: "A", frets: [-1, 0, 2, 2, 1, 0])
    /// ```
    init(_ name: String, root: String, frets: [Int]) {
        self.init(
            chord: GuitarChord(name),
            root: root,
            fingering: GuitarFingering(frets: frets)
        )
    }
}

/// "코드 이름 → 운지"의 **전사 공용 사전.** (ARCHITECTURE §3.3)
///
/// 프리셋 진행·커스텀 진행·기타넥 표시가 **전부 이 하나만** 본다.
/// 그래서 "커스텀 화면에서 프리셋이 쓰는 코드를 그대로 재사용"이 저절로 된다.
///
/// - Important: 커스텀 진행 화면이 코드를 고를 때는 **반드시 이 카탈로그에서** 고른다.
///   화면마다 별도 코드 목록을 만들면 "C코드"가 사람마다 달라진다.
protocol ChordCatalogProtocol {
    /// 사전에 있는 모든 코드 (데이터 표에 적힌 순서 그대로).
    var allChords: [GuitarChord] { get }

    /// 운지 조회. 사전에 없으면 `nil`.
    func fingering(for chord: GuitarChord) -> GuitarFingering?

    /// 근음으로 거르기 (선택 화면의 "C" 탭 등).
    func chords(root: String) -> [GuitarChord]

    /// 근음 목록 (표에 나온 순서, 중복 제거).
    var allRoots: [String] { get }
}

/// `Content/ChordCatalogData.swift`의 표를 읽어 동작하는 기본 카탈로그.
///
/// 코드를 추가하려면 **이 파일이 아니라 데이터 파일을** 고친다.
final class ChordCatalog: ChordCatalogProtocol {
    /// 앱 전역이 함께 보는 사전.
    static let shared = ChordCatalog(entries: ChordCatalogData.entries)

    let entries: [ChordEntry]

    private let fingeringsByChord: [GuitarChord: GuitarFingering]

    init(entries: [ChordEntry]) {
        self.entries = entries
        // 같은 이름이 두 번 적혀도 먼저 적힌 쪽이 이긴다 (표의 위쪽이 정답).
        self.fingeringsByChord = Dictionary(
            entries.map { ($0.chord, $0.fingering) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var allChords: [GuitarChord] { entries.map(\.chord) }

    var allRoots: [String] {
        var seen = Set<String>()
        return entries.compactMap { seen.insert($0.root).inserted ? $0.root : nil }
    }

    func fingering(for chord: GuitarChord) -> GuitarFingering? {
        fingeringsByChord[chord]
    }

    func chords(root: String) -> [GuitarChord] {
        entries.filter { $0.root == root }.map(\.chord)
    }

    func entry(for chord: GuitarChord) -> ChordEntry? {
        entries.first { $0.chord == chord }
    }
}

// MARK: - Mock

/// 어떤 코드를 물어도 같은 운지(C)를 돌려주는 가짜 사전. (ARCHITECTURE §4.1)
///
/// 카탈로그 데이터가 아직 안 채워졌어도 **화면·플레이어 개발을 시작할 수 있게** 한다.
final class MockChordCatalog: ChordCatalogProtocol {
    let allChords: [GuitarChord]
    private let stubFingering: GuitarFingering

    init(
        chords: [GuitarChord] = [.c, .g, .am, .em],
        stubFingering: GuitarFingering = .cMajor
    ) {
        self.allChords = chords
        self.stubFingering = stubFingering
    }

    var allRoots: [String] { allChords.map { String($0.rawValue.prefix(1)) } }

    func fingering(for chord: GuitarChord) -> GuitarFingering? {
        allChords.contains(chord) ? stubFingering : nil
    }

    func chords(root: String) -> [GuitarChord] {
        allChords.filter { $0.rawValue.hasPrefix(root) }
    }
}
