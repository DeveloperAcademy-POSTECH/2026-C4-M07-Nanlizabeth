import Combine
import Foundation

/// 프리셋은 `Content/`에서, 커스텀은 앱 문서 폴더의 JSON에서 읽는 기본 라이브러리.
/// (ARCHITECTURE §3.5, SPEC §7 저장 항목)
@MainActor
final class StrumPatternLibrary: StrumPatternLibraryProtocol, ObservableObject {
    @Published private(set) var customs: [StrumPattern] = []

    let presets: [StrumPattern]

    private let store: CustomPatternStore<StrumPattern>

    init(
        presets: [StrumPattern] = StrumPresetData.patterns,
        store: CustomPatternStore<StrumPattern> = CustomPatternStore(fileName: "custom-strum-patterns.json")
    ) {
        self.presets = presets
        self.store = store
        self.customs = store.load()
    }

    func saveCustom(_ pattern: StrumPattern) {
        var pattern = pattern
        pattern.source = .custom

        if let index = customs.firstIndex(where: { $0.id == pattern.id }) {
            customs[index] = pattern
        } else {
            customs.append(pattern)
        }
        store.save(customs)
    }

    func deleteCustom(id: UUID) {
        customs.removeAll { $0.id == id }
        store.save(customs)
    }

    func pattern(id: UUID) -> StrumPattern? {
        allPatterns.first { $0.id == id }
    }
}

/// 커스텀 프리셋을 JSON 파일로 저장·복원하는 작은 창고.
///
/// 모델이 `Codable`이기만 하면 주법이든 코드진행이든 **같은 창고를 쓴다** (SPEC §7).
struct CustomPatternStore<Item: Codable> {
    let fileName: String

    private var fileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    func load() -> [Item] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Item].self, from: data)) ?? []
    }

    func save(_ items: [Item]) {
        guard let fileURL else { return }
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[CustomPatternStore] \(fileName) 저장 실패: \(error.localizedDescription)")
            #endif
        }
    }
}
