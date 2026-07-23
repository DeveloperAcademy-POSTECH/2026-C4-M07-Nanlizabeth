import Combine
import Foundation

/// 박자 필터 — HI-FI의 `ALL / 4/4 / 3/4 …` 칩.
///
/// `TimeSignature`를 그대로 담지 않고 숫자 두 개로 푼 이유: 그 타입은 `Hashable`이 아니라
/// 칩 목록의 `id`로 쓸 수 없는데, **계약 파일(C1)을 건드리지 않으려고** 여기서 해결했다.
enum TimeSignatureFilter: Hashable {
    case all
    case signature(beatsPerBar: Int, noteValue: Int)

    init(_ timeSignature: TimeSignature) {
        self = .signature(
            beatsPerBar: timeSignature.beatsPerBar,
            noteValue: timeSignature.noteValue
        )
    }

    var label: String {
        switch self {
        case .all:
            return "ALL"
        case let .signature(beatsPerBar, noteValue):
            return "\(beatsPerBar)/\(noteValue)"
        }
    }

    func matches(_ timeSignature: TimeSignature) -> Bool {
        switch self {
        case .all:
            return true
        case let .signature(beatsPerBar, noteValue):
            return timeSignature.beatsPerBar == beatsPerBar
                && timeSignature.noteValue == noteValue
        }
    }
}

/// 화면 4 — 스트로크(주법) 선택의 상태. (ROADMAP 태스크 U4 · ARCHITECTURE §3.5)
///
/// **목록을 직접 갖지 않고 라이브러리에서 읽는다.** 그래서 CT1이 `Content/StrumPresetData.swift`에
/// 주법을 추가하면 **이 화면은 한 줄도 안 고쳐도** 항목이 늘어난다.
///
/// - Note: 고른 주법은 이 뷰모델이 들고 있다. 화면보다 오래 사는 곳(`AppRootView`)에 두어야
///   목록에 들어갔다 나와도 선택이 유지된다. 실제로 연주에 쓰는 연결은 L5(코디네이터)에서.
@MainActor
final class StrumSelectViewModel: ObservableObject {
    @Published var filter: TimeSignatureFilter = .all
    @Published private(set) var selectedID: UUID?

    private let library: StrumPatternLibraryProtocol
    private let preview: StrumPatternPreviewPlayer

    /// - Parameters:
    ///   - library: 테스트·프리뷰에서 Mock을 넣기 위한 자리. 비우면 실제 프리셋을 읽는다.
    ///   - preview: 미리듣기 플레이어. 비우면 실제 엔진으로 만든다.
    ///   기본값을 `nil`로 둔 이유: `@MainActor` 타입은 기본 인자 자리(비격리 문맥)에서
    ///   만들 수 없고, 격리된 `init` 안에서 만들어야 한다.
    init(library: StrumPatternLibraryProtocol? = nil, preview: StrumPatternPreviewPlayer? = nil) {
        self.library = library ?? StrumPatternLibrary()
        self.preview = preview ?? StrumPatternPreviewPlayer(engine: GuitarAudioEngineFactory.makeDefault())
    }

    /// 필터를 통과한 주법들.
    var patterns: [StrumPattern] {
        library.presets.filter { filter.matches($0.timeSignature) }
    }

    /// 화면에 띄울 필터 칩.
    ///
    /// **데이터에 실제로 있는 박자만** 칩으로 만든다 — 눌러도 빈 목록만 나오는 칩을 두지 않기
    /// 위해서다. CT1이 3/4·6/8 주법을 넣으면 화면을 안 고쳐도 칩이 저절로 생긴다.
    var availableFilters: [TimeSignatureFilter] {
        var unique: [TimeSignatureFilter] = []
        for filter in library.presets.map(\.timeSignature).map(TimeSignatureFilter.init)
        where !unique.contains(filter) {
            unique.append(filter)
        }
        return [.all] + unique
    }

    /// 칩 줄을 보여줄 필요가 있는가. **박자가 한 종류뿐이면 칩이 의미가 없다.**
    var showsFilters: Bool { availableFilters.count > 2 }

    var selectedPattern: StrumPattern? {
        guard let selectedID else { return nil }
        return library.pattern(id: selectedID)
    }

    func isSelected(_ pattern: StrumPattern) -> Bool {
        pattern.id == selectedID
    }

    /// 고르면 그 주법을 **C코드로 짧게 들려준다** (한 번에 하나만).
    func select(_ pattern: StrumPattern) {
        selectedID = pattern.id
        preview.preview(pattern)
    }

    /// 화면을 벗어날 때 미리듣기를 멈춘다.
    func stopPreview() {
        preview.stopPreview()
    }
}
