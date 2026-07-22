import Combine
import Foundation

// MARK: - 플러그 계약 (왼손 / 오른손)

/// **왼손 플러그** — "지금 무슨 코드를 짚고 있나"를 공급한다. (ARCHITECTURE §3.7)
///
/// 직접 짚든(넥 터치), 자동으로 짚히든(코드진행), 원격에서 받든(피어) —
/// 코디네이터 입장에선 **전부 똑같이 생겼다.**
@MainActor
protocol FingeringSourceProtocol: AnyObject {
    var currentFingering: GuitarFingering { get }
    var fingeringChanged: AnyPublisher<GuitarFingering, Never> { get }
}

/// **오른손 플러그** — "언제 어떻게 긁었나"를 방송한다. (ARCHITECTURE §3.7)
@MainActor
protocol StrumSourceProtocol: AnyObject {
    /// 6줄 전체를 훑는 스트럼.
    var strumOccurred: AnyPublisher<StrumOccurrence, Never> { get }
    /// 줄 하나만 튕기는 경우 (핑거피킹·개별 발음).
    var pluckOccurred: AnyPublisher<PluckOccurrence, Never> { get }
}

/// "지금 이렇게 긁었다".
struct StrumOccurrence: Equatable {
    let direction: StrumDirection
    let velocity: UInt8
    /// 줄 사이 시간차(초). 천천히 긁으면 커진다.
    let interval: TimeInterval
    let isMute: Bool

    init(
        direction: StrumDirection,
        velocity: UInt8,
        interval: TimeInterval = 0.035,
        isMute: Bool = false
    ) {
        self.direction = direction
        self.velocity = velocity
        self.interval = interval
        self.isMute = isMute
    }
}

/// "이 줄 하나만 튕겼다".
struct PluckOccurrence: Equatable {
    let stringIndex: Int
    let velocity: UInt8
}

// MARK: - 모드

/// 왼손·오른손 플러그의 조합. **모드 = 플러그 조합** (SPEC §2 조합표와 1:1)
enum PlayMode: String, CaseIterable, Identifiable {
    /// A. 코드 연습 — 내가 짚고(Manual), 자동으로 긁힌다(Auto).
    case chordPractice
    /// B. 스트로크 연습 — 자동으로 짚히고(Auto), 내가 긁는다(Manual).
    case strumPractice
    /// C. 합주(긁는 쪽 = iPad) — 원격에서 짚히고(Remote), 내가 긁는다(Manual).
    case ensembleStrummer
    /// C. 합주(짚는 쪽 = iPhone) — 내가 짚고 전송만 한다. **이 기기에선 소리가 안 난다.**
    case ensembleFingerer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chordPractice: return "코드 연습"
        case .strumPractice: return "스트로크 연습"
        case .ensembleStrummer: return "합주 (스트로크)"
        case .ensembleFingerer: return "합주 (코드)"
        }
    }

    /// 이 기기에서 소리가 나는가.
    ///
    /// 합주할 때 소리는 **긁는 기기(iPad)에서만** 난다 — 네트워크 지연이 스트럼 타이밍을
    /// 망치지 않게 하기 위한 결정 (`docs/adr/0001`).
    var producesSound: Bool {
        self != .ensembleFingerer
    }
}

// MARK: - 코디네이터

/// 왼손 플러그와 오른손 플러그를 꽂아 **소리로 만드는 멀티탭 본체.** (ARCHITECTURE §3.7 — 이 앱의 심장)
///
/// 하는 일은 딱 하나다: **오른손이 긁는 순간, 그 순간의 왼손 운지로 오디오를 호출한다.**
/// 왼손이 사람인지 자동인지 원격인지는 **알지도 못하고 알 필요도 없다.**
///
/// 그래서 모드를 늘려도 `if`문이 늘지 않는다 — 플러그 조합만 바뀐다.
///
/// ```swift
/// // 모드 A: 내가 짚고, 자동으로 긁힌다
/// coordinator.setSources(
///     fingering: ManualFingeringSource(state: fingeringState),
///     strum: AutoStrumSource(player: patternPlayer)
/// )
/// ```
@MainActor
final class PlaySessionCoordinator: ObservableObject {
    /// 지금 물려 있는 모드 (표시용).
    @Published private(set) var mode: PlayMode = .chordPractice
    /// 마지막으로 소리 낸 운지 (UI 디버깅용).
    @Published private(set) var lastPlayedFingering: GuitarFingering = .open

    /// 실제로 소리가 난 사건 — 줄 애니메이션(U3)과 햅틱(H1)이 구독한다.
    var notePlayed: AnyPublisher<NotePlayedEvent, Never> { notePlayedSubject.eraseToAnyPublisher() }

    /// **소리 게이트** — 지금 운지가 이 조건을 통과할 때만 소리를 낸다. (docs/PLAN-chord-drill §4-1)
    ///
    /// `nil`이면 항상 통과한다 — 기존 모드(A·B·C)는 이 값을 건드리지 않으므로 **동작이 그대로다.**
    /// 코드 드릴이 "정답 코드일 때만 소리"를 여기에 건다: 목표와 다른 운지면 획이 긁혀도 무음이고,
    /// 줄 떨림·햅틱(`notePlayed`)도 나가지 않는다.
    var soundGate: ((GuitarFingering) -> Bool)?

    private let notePlayedSubject = PassthroughSubject<NotePlayedEvent, Never>()
    private let audioEngine: GuitarAudioEngineProtocol?

    private var fingeringSource: FingeringSourceProtocol?
    private var strumSource: StrumSourceProtocol?
    private var cancellables: Set<AnyCancellable> = []

    init(audioEngine: GuitarAudioEngineProtocol?) {
        self.audioEngine = audioEngine
    }

    /// 플러그를 갈아끼운다. 이전 구독은 전부 정리된다.
    func setSources(
        mode: PlayMode = .chordPractice,
        fingering: FingeringSourceProtocol?,
        strum: StrumSourceProtocol?
    ) {
        cancellables.removeAll()
        self.mode = mode
        self.fingeringSource = fingering
        self.strumSource = strum

        guard mode.producesSound, let strum else { return }

        strum.strumOccurred
            .sink { [weak self] in self?.handleStrum($0) }
            .store(in: &cancellables)

        strum.pluckOccurred
            .sink { [weak self] in self?.handlePluck($0) }
            .store(in: &cancellables)
    }

    /// 소스는 그대로 두고 모드 표시만 바꾸고 싶을 때.
    func setMode(_ mode: PlayMode) {
        setSources(mode: mode, fingering: fingeringSource, strum: strumSource)
    }

    func stop() {
        cancellables.removeAll()
        audioEngine?.stopAllStrings()
    }

    // MARK: - 오른손 사건 → 소리

    private func handleStrum(_ occurrence: StrumOccurrence) {
        // ★ 여기가 핵심 — "긁은 그 순간"의 운지를 읽는다.
        let fingering = fingeringSource?.currentFingering ?? .open
        // 게이트가 닫혀 있으면 이 획은 통째로 무음 — 소리도, 줄 떨림·햅틱 방송도 없다.
        guard soundGate?(fingering) ?? true else { return }
        lastPlayedFingering = fingering

        audioEngine?.strum(
            frets: fingering.frets,
            direction: occurrence.direction,
            velocity: occurrence.velocity,
            interval: occurrence.interval
        )

        // 뮤트 스트로크는 소리가 거의 안 나므로 시각·햅틱 피드백도 약하게.
        let feedbackVelocity = occurrence.isMute ? occurrence.velocity / 2 : occurrence.velocity
        let order = occurrence.direction == .down
            ? Array(0..<GuitarFingering.stringCount)
            : Array((0..<GuitarFingering.stringCount).reversed())

        for stringIndex in order where fingering.isAudible(stringIndex: stringIndex) {
            notePlayedSubject.send(
                NotePlayedEvent(
                    stringIndex: stringIndex,
                    fret: fingering.frets[stringIndex],
                    velocity: feedbackVelocity
                )
            )
        }
    }

    private func handlePluck(_ occurrence: PluckOccurrence) {
        let fingering = fingeringSource?.currentFingering ?? .open
        guard soundGate?(fingering) ?? true else { return }
        guard fingering.isAudible(stringIndex: occurrence.stringIndex),
              let fret = fingering.fret(for: occurrence.stringIndex)
        else { return }

        lastPlayedFingering = fingering
        audioEngine?.pluckString(
            stringIndex: occurrence.stringIndex,
            fretNumber: fret,
            velocity: occurrence.velocity
        )
        notePlayedSubject.send(
            NotePlayedEvent(
                stringIndex: occurrence.stringIndex,
                fret: fret,
                velocity: occurrence.velocity
            )
        )
    }
}
