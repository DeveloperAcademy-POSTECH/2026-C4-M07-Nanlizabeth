import Combine
import Foundation

/// 화면 7 — 코드진행 커스텀의 상태. (ROADMAP 태스크 U6 · ARCHITECTURE §3.6)
///
/// 카탈로그에서 코드를 골라 진행을 만들고, 만드는 중에 **미리듣기**로 확인한 뒤 저장한다.
///
/// ## 재료는 프리셋과 같다
///
/// 여기서 고르는 코드는 **`ChordCatalog.shared`** 에서 온다 — 프리셋 진행이 쓰는 것과 완전히
/// 같은 카탈로그다. 그래서 "커스텀에서 프리셋 코드 재사용"이 저절로 된다 (SPEC 플로우2).
@MainActor
final class ProgressionCustomViewModel: ObservableObject {
    /// 지금까지 배치한 코드들.
    @Published var items: [ProgressionItem] = []
    @Published var name: String = "내 진행"
    /// 미리듣기 재생 중인가 (버튼 상태 표시).
    @Published private(set) var isPreviewing = false

    private let catalog: ChordCatalogProtocol
    private let library: ChordProgressionLibraryProtocol
    private let preview: ProgressionPreviewPlayerProtocol
    private var cancellables: Set<AnyCancellable> = []

    /// 실제 소리가 나는 기본 구성. 미리듣기 전용 엔진을 하나 들고 있다가 화면을 나가면 끈다.
    convenience init(library: ChordProgressionLibraryProtocol) {
        let engine = GuitarAudioEngineFactory.makeDefault()
        self.init(
            library: library,
            catalog: ChordCatalog.shared,
            preview: ProgressionPreviewPlayer(engine: engine)
        )
    }

    init(
        library: ChordProgressionLibraryProtocol,
        catalog: ChordCatalogProtocol,
        preview: ProgressionPreviewPlayerProtocol
    ) {
        self.library = library
        self.catalog = catalog
        self.preview = preview

        // 미리듣기 상태를 화면에 중계 (구현이 ObservableObject면 published를 잇는다).
        if let observable = preview as? ProgressionPreviewPlayer {
            observable.$isPreviewing
                .sink { [weak self] in self?.isPreviewing = $0 }
                .store(in: &cancellables)
        }
    }

    /// 카탈로그의 모든 코드. 화면의 코드 팔레트가 그린다.
    var catalogChords: [GuitarChord] { catalog.allChords }

    var canSave: Bool { !items.isEmpty }

    /// 지금 만들고 있는 진행.
    var currentProgression: ChordProgression {
        ChordProgression(name: displayName, items: items, source: .custom, recommendedBPM: 90)
    }

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "내 진행" : trimmed
    }

    // MARK: - 편집

    /// 코드를 진행 끝에 붙이고, **그 코드를 한 번 들려준다** (SPEC 플로우2 미리듣기).
    func addChord(_ chord: GuitarChord) {
        items.append(ProgressionItem(chord: chord))
        preview.previewChord(chord)
    }

    func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// 이 코드를 한 마디 더/덜 유지.
    func changeBars(of id: UUID, by delta: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].barCount = max(items[index].barCount + delta, 1)
    }

    // MARK: - 미리듣기

    /// 만든 진행 전체를 들어본다. **항상 하나만** 재생된다 (계약).
    func previewAll() {
        guard canSave else { return }
        preview.preview(currentProgression)
    }

    func stopPreview() {
        preview.stopPreview()
    }

    // MARK: - 저장

    /// 저장하고 저장된 진행을 돌려준다. (JSON 저장은 라이브러리가 한다 — SPEC §7)
    @discardableResult
    func save() -> ChordProgression {
        let progression = currentProgression
        library.saveCustom(progression)
        return progression
    }
}
