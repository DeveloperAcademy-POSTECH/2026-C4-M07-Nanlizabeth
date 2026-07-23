import Combine
import Foundation

/// 모드 C의 **iPad(긁는 쪽)** 세션. (ROADMAP 태스크 I3 · SPEC §2 모드 C)
///
/// **왼손은 원격(연결된 iPhone이 짚음), 오른손은 직접(내가 긁음).** 소리는 여기서 난다.
///
/// ```
///   연결된 iPhone ──운지 메시지──▶ RemoteFingeringBridge ──▶ RemoteFingeringSource ──┐
///                                                                                      ▼
///   iPad 스트럼 화면 ──긁기──▶ ManualStrumSource ──▶ Coordinator ──▶ AudioEngine (소리!)
/// ```
///
/// 모드 B(`StrumPracticeSession`)와 뼈대가 같다 — 왼손 플러그만 자동 진행에서 **원격**으로 바뀐다.
/// 그게 "플러그 조합만 바꾸면 모드가 된다"는 설계(§3.7)의 증거다.
@MainActor
final class EnsembleStrummerSession: ObservableObject {
    /// 스트럼 화면이 여기에 "긁었다"를 밀어 넣는다.
    let strumSource = ManualStrumSource()

    /// 지금 상대가 짚어 보낸 코드의 운지 (표시용).
    @Published private(set) var remoteFingering: GuitarFingering = .open

    var notePlayed: AnyPublisher<NotePlayedEvent, Never> { coordinator.notePlayed }

    private let engine: GuitarAudioEngineProtocol?
    private let remoteSource = RemoteFingeringSource()
    private let coordinator: PlaySessionCoordinator
    private let bridge: RemoteFingeringBridge
    private var cancellables: Set<AnyCancellable> = []

    init(engine: GuitarAudioEngineProtocol?, multipeer: MultipeerServiceProtocol) {
        let coordinator = PlaySessionCoordinator(audioEngine: engine)

        // 왼손 = 원격 운지, 오른손 = 내 손.
        coordinator.setSources(
            mode: .ensembleStrummer,
            fingering: remoteSource,
            strum: strumSource
        )

        self.engine = engine
        self.coordinator = coordinator
        self.bridge = RemoteFingeringBridge(multipeer: multipeer, target: remoteSource)

        // 원격 운지를 표시용으로 중계.
        remoteSource.$currentFingering
            .sink { [weak self] in self?.remoteFingering = $0 }
            .store(in: &cancellables)
    }

    func startEngine() {
        engine?.start()
    }

    /// 내가 긁었다고 알린다. 스트럼 화면이 부른다.
    func strum(direction: StrumDirection, velocity: UInt8, interval: TimeInterval = 0.035) {
        strumSource.strum(direction: direction, velocity: velocity, interval: interval)
    }

    func end() {
        coordinator.stop()
        engine?.stop()
    }
}
