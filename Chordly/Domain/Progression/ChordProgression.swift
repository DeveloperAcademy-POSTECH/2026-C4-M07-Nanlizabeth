import Combine
import Foundation

// MARK: - 모델

/// 진행의 한 칸. "이 코드를 몇 마디".
struct ProgressionItem: Equatable, Codable, Identifiable {
    var id: UUID = UUID()
    var chord: GuitarChord
    var barCount: Int

    init(id: UUID = UUID(), chord: GuitarChord, barCount: Int = 1) {
        self.id = id
        self.chord = chord
        self.barCount = max(barCount, 1)
    }

    /// 데이터 표를 짧게 적기 위한 편의 생성자.
    ///
    /// ```swift
    /// ProgressionItem("C"), ProgressionItem("G", bars: 2)
    /// ```
    init(_ chordName: String, bars: Int = 1) {
        self.init(chord: GuitarChord(chordName), barCount: bars)
    }
}

/// 코드가 바뀌는 순서. (ARCHITECTURE §3.6)
struct ChordProgression: Equatable, Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var items: [ProgressionItem]
    var source: PatternSource
    /// 권장 BPM. 미리듣기의 기본값.
    var recommendedBPM: Double

    init(
        id: UUID = UUID(),
        name: String,
        items: [ProgressionItem],
        source: PatternSource = .preset,
        recommendedBPM: Double = 90
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.source = source
        self.recommendedBPM = recommendedBPM
    }

    /// 진행 전체가 몇 마디인가.
    var totalBars: Int {
        items.reduce(0) { $0 + $1.barCount }
    }

    /// `bar`번째 마디에서 짚어야 할 코드. 진행보다 뒤면 `nil`.
    ///
    /// 반복 재생 시에는 호출 전에 `bar % totalBars`로 접어 넣는다.
    func chord(atBar bar: Int) -> GuitarChord? {
        guard bar >= 0 else { return nil }
        var cursor = 0
        for item in items {
            if bar < cursor + item.barCount { return item.chord }
            cursor += item.barCount
        }
        return nil
    }

    /// 루프까지 감안한 조회. 진행이 비어 있으면 `nil`.
    func loopedChord(atBar bar: Int) -> GuitarChord? {
        guard totalBars > 0 else { return nil }
        return chord(atBar: ((bar % totalBars) + totalBars) % totalBars)
    }
}

// MARK: - 라이브러리 계약

/// 코드진행 목록을 갖고 있고 커스텀을 저장하는 곳. (ARCHITECTURE §3.6)
@MainActor
protocol ChordProgressionLibraryProtocol: AnyObject {
    /// 기본 제공 진행 (`Content/ProgressionPresetData.swift`).
    var presets: [ChordProgression] { get }
    var customs: [ChordProgression] { get }

    func saveCustom(_ progression: ChordProgression)
    func deleteCustom(id: UUID)
    func progression(id: UUID) -> ChordProgression?
}

extension ChordProgressionLibraryProtocol {
    var allProgressions: [ChordProgression] { presets + customs }
}

// MARK: - 플레이어 계약

/// 진행을 클럭에 맞춰 자동으로 짚어준다. **모드 B의 "자동 왼손".** (ARCHITECTURE §3.6)
@MainActor
protocol ChordProgressionPlayerProtocol: AnyObject {
    var isPlaying: Bool { get }
    /// 지금 짚고 있는 코드.
    var currentChord: GuitarChord? { get }
    /// 위 코드의 운지 — 오른손이 긁을 때 이 값을 쓴다.
    var currentFingering: GuitarFingering { get }
    /// 코드가 바뀌는 순간 방송. 화면의 "다음 코드" 표시가 구독한다.
    var chordChanged: AnyPublisher<GuitarChord, Never> { get }

    func start(progression: ChordProgression, bpm: Double, looping: Bool)
    func stop()
}

/// 선택 전에 짧게 들어보기. (ARCHITECTURE §3.6)
///
/// - Important: **항상 하나만 재생된다.** 새 미리듣기가 이전 것을 자동으로 멈춘다.
@MainActor
protocol ProgressionPreviewPlayerProtocol: AnyObject {
    var isPreviewing: Bool { get }

    /// 진행 전체를 기본 주법·기본 BPM으로 짧게 재생.
    func preview(_ progression: ChordProgression)
    /// 코드 하나만 한 번 울리기 (커스텀 화면에서 코드 탭했을 때).
    func previewChord(_ chord: GuitarChord)
    func stopPreview()
}

// MARK: - Mock

/// 하드코딩 프리셋을 돌려주는 가짜 라이브러리. (ARCHITECTURE §4.1)
///
/// **진행 선택 화면(U5)·커스텀 화면(U6)을 진짜 데이터 없이 완성할 수 있게** 한다.
@MainActor
final class MockChordProgressionLibrary: ChordProgressionLibraryProtocol, ObservableObject {
    @Published private(set) var customs: [ChordProgression] = []

    let presets: [ChordProgression]

    init(presets: [ChordProgression]? = nil) {
        self.presets = presets ?? Self.stubPresets
    }

    func saveCustom(_ progression: ChordProgression) {
        if let index = customs.firstIndex(where: { $0.id == progression.id }) {
            customs[index] = progression
        } else {
            customs.append(progression)
        }
    }

    func deleteCustom(id: UUID) {
        customs.removeAll { $0.id == id }
    }

    func progression(id: UUID) -> ChordProgression? {
        allProgressions.first { $0.id == id }
    }

    /// 화면 개발용 가짜 프리셋. 진짜 데이터는 CT2가 `Content/`에 채운다.
    static let stubPresets: [ChordProgression] = [
        ChordProgression(
            name: "머니코드",
            items: [ProgressionItem("C"), ProgressionItem("G"), ProgressionItem("Am"), ProgressionItem("F")],
            recommendedBPM: 80
        ),
        ChordProgression(
            name: "기본 3코드",
            items: [ProgressionItem("C", bars: 2), ProgressionItem("F"), ProgressionItem("G")],
            recommendedBPM: 90
        ),
    ]
}

/// 정해둔 간격마다 코드가 바뀌는 척하는 가짜 플레이어. (ARCHITECTURE §4.1)
///
/// **모드 B 화면을 진짜 플레이어 없이 개발**할 수 있게 한다.
/// 실제 시간을 쓰지 않고 `advance()`로 손으로 넘기므로 테스트에도 그대로 쓴다.
@MainActor
final class MockChordProgressionPlayer: ChordProgressionPlayerProtocol, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentChord: GuitarChord?

    var currentFingering: GuitarFingering { currentChord?.fingering ?? .open }
    var chordChanged: AnyPublisher<GuitarChord, Never> { subject.eraseToAnyPublisher() }

    private let subject = PassthroughSubject<GuitarChord, Never>()
    private var progression: ChordProgression?
    private var barCursor = 0

    func start(progression: ChordProgression, bpm: Double, looping: Bool) {
        self.progression = progression
        barCursor = 0
        isPlaying = true
        updateChord()
    }

    func stop() {
        isPlaying = false
        currentChord = nil
    }

    /// 다음 마디로 넘긴다 (테스트·프리뷰용).
    func advanceBar() {
        guard isPlaying else { return }
        barCursor += 1
        updateChord()
    }

    private func updateChord() {
        guard let chord = progression?.loopedChord(atBar: barCursor) else { return }
        guard chord != currentChord else { return }
        currentChord = chord
        subject.send(chord)
    }
}

/// 시스템 효과음으로 대신하는 가짜 미리듣기.
///
/// 기존 `MockSoundPreviewService`와 같은 발상이다 — 진짜 오디오 없이 "재생됐다"는 감각만 준다.
@MainActor
final class MockProgressionPreviewPlayer: ProgressionPreviewPlayerProtocol, ObservableObject {
    @Published private(set) var isPreviewing = false

    /// 마지막으로 미리들은 대상 (테스트 검증용).
    private(set) var lastPreviewedChord: GuitarChord?
    private(set) var lastPreviewedProgression: ChordProgression?

    private let soundPreview: SoundPreviewServiceProtocol

    init(soundPreview: SoundPreviewServiceProtocol = MockSoundPreviewService()) {
        self.soundPreview = soundPreview
    }

    func preview(_ progression: ChordProgression) {
        stopPreview()
        lastPreviewedProgression = progression
        isPreviewing = true
        soundPreview.playMockChord(progression.items.first?.chord)
    }

    func previewChord(_ chord: GuitarChord) {
        stopPreview()
        lastPreviewedChord = chord
        isPreviewing = true
        soundPreview.playMockChord(chord)
    }

    func stopPreview() {
        isPreviewing = false
    }
}
