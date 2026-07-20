import Combine
import Foundation

/// 화면 6 — 코드진행 선택의 상태. (ROADMAP 태스크 U5 · ARCHITECTURE §3.6)
///
/// U4(스트로크 선택)와 같은 꼴이다 — **목록을 직접 갖지 않고 라이브러리에서 읽는다.**
/// CT2가 `Content/ProgressionPresetData.swift`에 진행을 추가하면 화면은 안 고쳐도 늘어난다.
/// 프리셋과 사용자가 만든 커스텀을 함께 보여준다.
@MainActor
final class ProgressionSelectViewModel: ObservableObject {
    /// 라이브러리의 커스텀 목록 변화를 화면에 반영하기 위해 관찰한다.
    @Published private(set) var selectedID: UUID?

    let library: ChordProgressionLibraryProtocol

    private var cancellable: AnyCancellable?

    init(library: ChordProgressionLibraryProtocol? = nil) {
        let resolved = library ?? ChordProgressionLibrary()
        self.library = resolved

        // 커스텀 화면(U6)에서 새 진행을 저장하면 라이브러리의 customs가 바뀐다.
        // 그걸 이 화면에 흘려보내 목록이 저절로 갱신되게 한다.
        if let observable = resolved as? ChordProgressionLibrary {
            cancellable = observable.objectWillChange
                .sink { [weak self] in self?.objectWillChange.send() }
        } else if let observable = resolved as? MockChordProgressionLibrary {
            cancellable = observable.objectWillChange
                .sink { [weak self] in self?.objectWillChange.send() }
        }
    }

    /// 프리셋 먼저, 그다음 커스텀.
    var progressions: [ChordProgression] {
        library.allProgressions
    }

    var selectedProgression: ChordProgression? {
        guard let selectedID else { return nil }
        return library.progression(id: selectedID)
    }

    func isSelected(_ progression: ChordProgression) -> Bool {
        progression.id == selectedID
    }

    func select(_ progression: ChordProgression) {
        selectedID = progression.id
    }
}
