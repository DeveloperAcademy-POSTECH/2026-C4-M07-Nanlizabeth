/// 사용자가 짚은 운지를 카탈로그 코드의 실제 보이싱으로 해석한다.
///
/// 판정은 초보자에게 관대하게 뮤트와 개방현 차이를 봐주지만, 실제 소리는 카탈로그의
/// `-1` 뮤트 현을 따라야 한다. 이 레이어가 그 사이를 이어 준다.
enum ChordVoicingResolver {
    static func resolvedVoicing(for played: GuitarFingering, catalog: ChordCatalog = .shared) -> GuitarFingering? {
        matchingEntry(for: played, catalog: catalog)?.fingering
    }

    static func matchingEntry(for played: GuitarFingering, catalog: ChordCatalog = .shared) -> ChordEntry? {
        catalog.entries
            .filter { ChordJudge.matches(played: played.frets, target: $0.fingering.frets) }
            .max { score(played: played, entry: $0) < score(played: played, entry: $1) }
    }

    private static func score(played: GuitarFingering, entry: ChordEntry) -> Int {
        var score = 0

        for index in 0..<GuitarFingering.stringCount {
            let playedFret = normalized(played.frets[index])
            let targetFret = normalized(entry.fingering.frets[index])

            if playedFret == targetFret {
                score += targetFret > 0 ? 4 : 1
            }

            if played.frets[index] == entry.fingering.frets[index] {
                score += 2
            }
        }

        return score
    }

    private static func normalized(_ fret: Int) -> Int {
        fret <= 0 ? 0 : fret
    }
}
