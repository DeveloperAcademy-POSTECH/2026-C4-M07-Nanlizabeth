import Combine
import Foundation

// MARK: - 왼손 플러그 3종

/// 🖐️ **직접** — 넥 화면을 손가락으로 짚는다. `FingeringState`(§3.4)를 감싼 것뿐이다.
@MainActor
final class ManualFingeringSource: FingeringSourceProtocol {
    private let state: FingeringStateProtocol

    init(state: FingeringStateProtocol) {
        self.state = state
    }

    var currentFingering: GuitarFingering { state.currentFingering }
    var fingeringChanged: AnyPublisher<GuitarFingering, Never> { state.fingeringChanged }
}

/// 🤖 **자동** — 정해둔 코드진행이 시간 따라 저절로 짚힌다. **모드 B의 왼손.**
@MainActor
final class AutoFingeringSource: FingeringSourceProtocol {
    private let player: ChordProgressionPlayerProtocol

    init(player: ChordProgressionPlayerProtocol) {
        self.player = player
    }

    var currentFingering: GuitarFingering { player.currentFingering }

    var fingeringChanged: AnyPublisher<GuitarFingering, Never> {
        player.chordChanged
            .map(\.fingering)
            .eraseToAnyPublisher()
    }
}

/// 📡 **원격** — 연결된 아이폰이 짚은 걸 실시간으로 받는다. **모드 C(iPad 쪽)의 왼손.**
///
/// 통신 레인(N1)이 수신 메시지를 여기에 밀어 넣으면, **코디네이터는 원격인지도 모른 채** 동작한다.
///
/// ```swift
/// multipeerService.onMessageReceived = { message, _ in
///     if case .fingering = message.type, let frets = message.frets {
///         remoteSource.update(GuitarFingering(frets: frets))
///     }
/// }
/// ```
@MainActor
final class RemoteFingeringSource: FingeringSourceProtocol, ObservableObject {
    @Published private(set) var currentFingering: GuitarFingering = .open

    var fingeringChanged: AnyPublisher<GuitarFingering, Never> { $currentFingering.eraseToAnyPublisher() }

    /// 피어에게서 새 운지를 받았을 때 호출한다.
    func update(_ fingering: GuitarFingering) {
        currentFingering = fingering
    }
}

// MARK: - 오른손 플러그 3종

/// 🖐️ **직접** — 줄 화면을 손가락으로 긁는다. 스트럼 화면 UI가 여기에 사건을 밀어 넣는다.
@MainActor
final class ManualStrumSource: StrumSourceProtocol {
    var strumOccurred: AnyPublisher<StrumOccurrence, Never> { strumSubject.eraseToAnyPublisher() }
    var pluckOccurred: AnyPublisher<PluckOccurrence, Never> { pluckSubject.eraseToAnyPublisher() }

    private let strumSubject = PassthroughSubject<StrumOccurrence, Never>()
    private let pluckSubject = PassthroughSubject<PluckOccurrence, Never>()

    /// UI가 "긁혔다"고 알릴 때 호출한다.
    func strum(direction: StrumDirection, velocity: UInt8, interval: TimeInterval = 0.035) {
        strumSubject.send(StrumOccurrence(direction: direction, velocity: velocity, interval: interval))
    }

    /// UI가 "이 줄만 튕겼다"고 알릴 때 호출한다.
    func pluck(stringIndex: Int, velocity: UInt8) {
        pluckSubject.send(PluckOccurrence(stringIndex: stringIndex, velocity: velocity))
    }
}

/// 🤖 **자동** — 고른 주법이 박자 따라 저절로 긁는다. **모드 A의 오른손.**
@MainActor
final class AutoStrumSource: StrumSourceProtocol {
    var strumOccurred: AnyPublisher<StrumOccurrence, Never> {
        player.strumPerformed
            .map {
                StrumOccurrence(
                    direction: $0.direction,
                    velocity: $0.velocity,
                    isMute: $0.isMute
                )
            }
            .eraseToAnyPublisher()
    }

    /// 자동 주법은 줄 하나만 튕기지 않는다.
    var pluckOccurred: AnyPublisher<PluckOccurrence, Never> {
        Empty().eraseToAnyPublisher()
    }

    private let player: StrumPatternPlayerProtocol

    init(player: StrumPatternPlayerProtocol) {
        self.player = player
    }
}

/// 📡 **원격** — 연결된 아이패드가 긁은 걸 실시간으로 받는다.
///
/// - Note: 현재 설계에선 소리가 **긁는 기기에서** 나므로 이 소스는 쓰이지 않는다.
///   합주 형태가 늘어날 때를 위해 계약만 맞춰 열어둔다 (ARCHITECTURE §3.7).
@MainActor
final class RemoteStrumSource: StrumSourceProtocol {
    var strumOccurred: AnyPublisher<StrumOccurrence, Never> { strumSubject.eraseToAnyPublisher() }
    var pluckOccurred: AnyPublisher<PluckOccurrence, Never> { pluckSubject.eraseToAnyPublisher() }

    private let strumSubject = PassthroughSubject<StrumOccurrence, Never>()
    private let pluckSubject = PassthroughSubject<PluckOccurrence, Never>()

    func receiveStrum(direction: StrumDirection, velocity: UInt8) {
        strumSubject.send(StrumOccurrence(direction: direction, velocity: velocity))
    }

    func receivePluck(stringIndex: Int, velocity: UInt8) {
        pluckSubject.send(PluckOccurrence(stringIndex: stringIndex, velocity: velocity))
    }
}

// MARK: - Mock

/// 정해둔 코드 하나를 계속 내놓는 가짜 왼손. (ARCHITECTURE §4.1)
@MainActor
final class MockFingeringSource: FingeringSourceProtocol, ObservableObject {
    @Published private(set) var currentFingering: GuitarFingering

    var fingeringChanged: AnyPublisher<GuitarFingering, Never> { $currentFingering.eraseToAnyPublisher() }

    init(chord: GuitarChord = .c) {
        self.currentFingering = chord.fingering
    }

    /// 테스트에서 손으로 코드를 바꾼다.
    func set(_ chord: GuitarChord) {
        currentFingering = chord.fingering
    }
}

/// 손으로 "긁었다"를 발생시키는 가짜 오른손. (ARCHITECTURE §4.1)
///
/// 코디네이터·소리 경로를 UI 없이 검증할 때 쓴다.
@MainActor
final class MockStrumSource: StrumSourceProtocol {
    var strumOccurred: AnyPublisher<StrumOccurrence, Never> { strumSubject.eraseToAnyPublisher() }
    var pluckOccurred: AnyPublisher<PluckOccurrence, Never> { pluckSubject.eraseToAnyPublisher() }

    private let strumSubject = PassthroughSubject<StrumOccurrence, Never>()
    private let pluckSubject = PassthroughSubject<PluckOccurrence, Never>()

    func emitStrum(_ direction: StrumDirection = .down, velocity: UInt8 = 96) {
        strumSubject.send(StrumOccurrence(direction: direction, velocity: velocity))
    }

    func emitPluck(stringIndex: Int, velocity: UInt8 = 96) {
        pluckSubject.send(PluckOccurrence(stringIndex: stringIndex, velocity: velocity))
    }
}
