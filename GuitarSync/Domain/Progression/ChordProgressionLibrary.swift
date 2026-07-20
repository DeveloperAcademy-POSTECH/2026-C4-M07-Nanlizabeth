import Combine
import Foundation

/// 프리셋은 `Content/`에서, 커스텀은 앱 문서 폴더의 JSON에서 읽는 기본 라이브러리.
/// (ARCHITECTURE §3.6, SPEC §7 저장 항목)
@MainActor
final class ChordProgressionLibrary: ChordProgressionLibraryProtocol, ObservableObject {
    @Published private(set) var customs: [ChordProgression] = []

    let presets: [ChordProgression]

    private let store: CustomPatternStore<ChordProgression>

    init(
        presets: [ChordProgression] = ProgressionPresetData.progressions,
        store: CustomPatternStore<ChordProgression> = CustomPatternStore(fileName: "custom-progressions.json")
    ) {
        self.presets = presets
        self.store = store
        self.customs = store.load()
    }

    func saveCustom(_ progression: ChordProgression) {
        var progression = progression
        progression.source = .custom

        if let index = customs.firstIndex(where: { $0.id == progression.id }) {
            customs[index] = progression
        } else {
            customs.append(progression)
        }
        store.save(customs)
    }

    func deleteCustom(id: UUID) {
        customs.removeAll { $0.id == id }
        store.save(customs)
    }

    func progression(id: UUID) -> ChordProgression? {
        allProgressions.first { $0.id == id }
    }
}
