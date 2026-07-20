import Combine
import Foundation

// MARK: - 주고받는 값

/// 터치 한 개의 의미: "몇 번 줄 몇 프렛이 눌렸다".
///
/// UI는 터치 좌표를 이걸로 바꿔서 넘기기만 하면 되고, 소리·상태 로직은 몰라도 된다.
struct FretPress: Hashable, Codable {
    /// `0` = 6번줄(저음 E) … `5` = 1번줄(고음 E)
    let stringIndex: Int
    /// `0` = 개방현 · `1~` = 프렛 번호
    let fret: Int

    init(stringIndex: Int, fret: Int) {
        self.stringIndex = stringIndex
        self.fret = fret
    }
}

/// "이 줄이 울렸다" 방송. UI 애니메이션(U3)과 햅틱(H1)이 **같은 이 이벤트**를 구독한다.
struct NotePlayedEvent: Equatable {
    let stringIndex: Int
    let fret: Int
    /// 0~127. 화면 진폭·글로우 세기와 햅틱 강도에 그대로 쓴다.
    let velocity: UInt8
}

/// 프렛을 눌렀을 때 소리를 낼지 말지.
enum FretSoundPolicy {
    /// 누르는 순간 그 줄이 울린다. **모드 A·C의 기타넥** (SPEC §4 개별 발음).
    case pluckOnPress
    /// 짚기만 하고 소리는 안 난다. 오른손이 긁을 때만 울리는 상황용.
    case silent
}

/// 아무도 안 짚은 줄을 어떻게 볼 것인가.
///
/// - Note: ⚠️ **SPEC §8 열린 결정** — "모드 A에서 아무 코드도 안 짚었을 때 개방현인가 무음인가".
///   결정되면 기본값을 바꾸면 된다. 그때까지는 호출부에서 골라 쓸 수 있게 열어둔다.
enum UnpressedStringPolicy {
    /// 안 짚은 줄은 개방현으로 친다 (실제 기타와 같음).
    case open
    /// 안 짚은 줄은 뮤트 — 짚은 줄만 소리 난다.
    case muted

    var fretValue: Int {
        switch self {
        case .open: return 0
        case .muted: return -1
        }
    }
}

// MARK: - 계약

/// 기타넥 터치를 받아 ①운지 상태를 관리하고 ②정책대로 즉시 발음시키고
/// ③UI가 그릴 이벤트를 되돌려준다. (ARCHITECTURE §3.4 — SPEC §4의 해답)
///
/// **이 계약의 핵심은 "서로의 속사정을 모른다"는 것이다.**
/// - UI는 터치 → `FretPress` 변환과 `notePlayed` 구독만 하면 된다. 소리 로직을 몰라도 된다.
/// - 로직은 터치가 어떻게 들어오는지 몰라도 된다. `Set<FretPress>`만 받으면 끝.
///
/// ```swift
/// // [UI 쪽]
/// state.pressesChanged(currentTouches.map(FretPress.init))   // 지금 눌린 것 전부를 통째로
/// cancellable = state.notePlayed.sink { animateString($0.stringIndex, $0.velocity) }
///
/// // [로직 쪽] 아무것도 안 해도 된다 — 위 호출만 오면 소리는 알아서 난다.
/// ```
@MainActor
protocol FingeringStateProtocol: AnyObject {
    /// 지금 짚고 있는 운지. UI 표시·멀티피어 전송·자동 스트럼이 **공용으로** 본다.
    var currentFingering: GuitarFingering { get }
    /// 위 값의 변화 스트림.
    var fingeringChanged: AnyPublisher<GuitarFingering, Never> { get }
    /// 줄이 울릴 때마다 방송. UI 애니메이션·햅틱이 구독한다.
    var notePlayed: AnyPublisher<NotePlayedEvent, Never> { get }

    var soundPolicy: FretSoundPolicy { get set }

    /// **UI가 호출한다.** 지금 눌려 있는 칸을 *통째로* 넘긴다.
    ///
    /// began/ended를 낱개로 받지 않고 **스냅샷**으로 받는 이유: 멀티터치에서 이벤트 순서가
    /// 꼬여도 상태가 어긋나지 않는다. "지금 이게 전부다"라고만 말하면 된다.
    func pressesChanged(_ presses: Set<FretPress>)

    /// 손을 다 뗐을 때 (화면 이탈 등).
    func releaseAll()
}

// MARK: - 기본 구현

/// `FingeringStateProtocol`의 실제 구현. 오디오 엔진에 직접 발음을 지시한다.
@MainActor
final class FingeringState: FingeringStateProtocol, ObservableObject {
    @Published private(set) var currentFingering: GuitarFingering
    var soundPolicy: FretSoundPolicy

    /// 안 짚은 줄의 취급 (SPEC §8 결정 대기).
    var unpressedPolicy: UnpressedStringPolicy

    /// 터치엔 세기 정보가 없으므로 고정 세기를 쓴다.
    /// (실제 기타의 "왼손 해머링" 세기에 해당 — 오른손 스트럼보다 약하게 잡았다)
    var pressVelocity: UInt8

    var fingeringChanged: AnyPublisher<GuitarFingering, Never> { $currentFingering.eraseToAnyPublisher() }
    var notePlayed: AnyPublisher<NotePlayedEvent, Never> { notePlayedSubject.eraseToAnyPublisher() }

    private let notePlayedSubject = PassthroughSubject<NotePlayedEvent, Never>()
    private let audioEngine: GuitarAudioEngineProtocol?
    private var activePresses: Set<FretPress> = []

    init(
        audioEngine: GuitarAudioEngineProtocol?,
        soundPolicy: FretSoundPolicy = .pluckOnPress,
        unpressedPolicy: UnpressedStringPolicy = .open,
        pressVelocity: UInt8 = 88
    ) {
        self.audioEngine = audioEngine
        self.soundPolicy = soundPolicy
        self.unpressedPolicy = unpressedPolicy
        self.pressVelocity = pressVelocity
        self.currentFingering = Self.fingering(from: [], unpressedPolicy: unpressedPolicy)
    }

    func pressesChanged(_ presses: Set<FretPress>) {
        let valid = presses.filter { (0..<GuitarFingering.stringCount).contains($0.stringIndex) && $0.fret >= 0 }
        // 이번에 "새로" 눌린 것만 발음한다. 계속 누르고 있는 손가락이 매 프레임 다시 울리면 안 된다.
        let newlyPressed = valid.subtracting(activePresses)

        activePresses = valid
        currentFingering = Self.fingering(from: valid, unpressedPolicy: unpressedPolicy)

        guard soundPolicy == .pluckOnPress else { return }

        // 한 줄에 손가락이 여러 개 얹혔으면 실제 기타처럼 **가장 높은 프렛**만 울린다.
        let soundingFrets = Dictionary(grouping: newlyPressed, by: \.stringIndex)
            .compactMapValues { $0.map(\.fret).max() }

        for (stringIndex, fret) in soundingFrets.sorted(by: { $0.key < $1.key }) {
            audioEngine?.pluckString(stringIndex: stringIndex, fretNumber: fret, velocity: pressVelocity)
            notePlayedSubject.send(
                NotePlayedEvent(stringIndex: stringIndex, fret: fret, velocity: pressVelocity)
            )
        }
    }

    func releaseAll() {
        activePresses = []
        currentFingering = Self.fingering(from: [], unpressedPolicy: unpressedPolicy)
        audioEngine?.stopAllStrings()
    }

    /// 눌린 칸 모음 → 6줄 운지. 한 줄에 여러 개면 **가장 높은 프렛**이 이긴다(실제 기타와 동일).
    private static func fingering(
        from presses: Set<FretPress>,
        unpressedPolicy: UnpressedStringPolicy
    ) -> GuitarFingering {
        var frets = Array(repeating: unpressedPolicy.fretValue, count: GuitarFingering.stringCount)
        for press in presses where frets.indices.contains(press.stringIndex) {
            frets[press.stringIndex] = max(frets[press.stringIndex], press.fret)
        }
        return GuitarFingering(frets: frets)
    }
}

// MARK: - Mock

/// 어떤 터치가 들어와도 **정해둔 코드 하나**로 응답하는 가짜 운지 상태. (ARCHITECTURE §4.1)
///
/// 넥 화면 UI를 진짜 로직 없이 개발할 때 쓴다. 소리는 안 나지만 `notePlayed`는 방송하므로
/// **줄 애니메이션과 햅틱 개발까지** 이걸로 가능하다.
///
/// ```swift
/// let state = MockFingeringState(stubChord: .am)
/// NeckView(state: state)   // 아무 데나 눌러도 Am이 짚힌 것으로 보인다
/// ```
@MainActor
final class MockFingeringState: FingeringStateProtocol, ObservableObject {
    @Published private(set) var currentFingering: GuitarFingering
    var soundPolicy: FretSoundPolicy = .pluckOnPress

    var fingeringChanged: AnyPublisher<GuitarFingering, Never> { $currentFingering.eraseToAnyPublisher() }
    var notePlayed: AnyPublisher<NotePlayedEvent, Never> { notePlayedSubject.eraseToAnyPublisher() }

    /// 마지막으로 받은 터치 (테스트 검증용).
    private(set) var lastPresses: Set<FretPress> = []

    private let notePlayedSubject = PassthroughSubject<NotePlayedEvent, Never>()
    private let stubFingering: GuitarFingering

    init(stubChord: GuitarChord = .c) {
        self.stubFingering = stubChord.fingering
        self.currentFingering = stubChord.fingering
    }

    func pressesChanged(_ presses: Set<FretPress>) {
        lastPresses = presses
        currentFingering = presses.isEmpty ? .open : stubFingering

        for press in presses.sorted(by: { $0.stringIndex < $1.stringIndex }) {
            notePlayedSubject.send(
                NotePlayedEvent(stringIndex: press.stringIndex, fret: press.fret, velocity: 96)
            )
        }
    }

    func releaseAll() {
        lastPresses = []
        currentFingering = .open
    }
}

extension FretPress: Comparable {
    static func < (lhs: FretPress, rhs: FretPress) -> Bool {
        (lhs.stringIndex, lhs.fret) < (rhs.stringIndex, rhs.fret)
    }
}
