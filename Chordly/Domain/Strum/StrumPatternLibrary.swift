import Combine
import Foundation

/// 프리셋 주법을 `Content/`에서 읽어오는 기본 라이브러리. (ARCHITECTURE §3.5)
///
/// - Note: **읽기 전용입니다.** 주법 커스텀은 지원하지 않기로 했습니다 (2026-07-20).
///   사용자가 만드는 건 코드진행뿐이라, 저장 로직은 `ChordProgressionLibrary`에만 있습니다.
@MainActor
final class StrumPatternLibrary: StrumPatternLibraryProtocol, ObservableObject {
    let presets: [StrumPattern]

    init(presets: [StrumPattern] = StrumPresetData.patterns) {
        self.presets = presets
    }

    func pattern(id: UUID) -> StrumPattern? {
        presets.first { $0.id == id }
    }
}

/// 커스텀 항목을 JSON 파일로 저장·복원하는 작은 창고.
///
/// 현재 쓰는 곳은 **코드진행 하나**뿐이지만, 모델이 `Codable`이기만 하면 무엇이든 담을 수 있게
/// 제네릭으로 두었다 (SPEC §7).
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
