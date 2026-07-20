import Combine
import Foundation

/// 기타넥 화면의 상태. (ROADMAP 태스크 U2 · ARCHITECTURE §3.4)
///
/// **소리 로직은 전혀 모른다.** 하는 일은 딱 둘이다:
/// 1. 터치로 만들어진 `FretPress` 묶음을 `FingeringStateProtocol`에 그대로 넘긴다
/// 2. 돌아오는 방송(`fingeringChanged`·`notePlayed`)을 구독해 화면이 그릴 값으로 바꾼다
///
/// 덕분에 로직 담당(L1)이 아직 작업 중이어도 `MockFingeringState`로 화면을 끝까지 만들 수 있다.
@MainActor
final class NeckViewModel: ObservableObject {
    /// 지금 짚힌 운지. 화면 표시용이자, 나중에 멀티피어 전송이 그대로 쓸 값이다.
    @Published private(set) var fingering: GuitarFingering = .open

    /// 지금 손가락이 닿아 있는 칸. 짚은 자리 점을 그리는 데 쓴다.
    @Published private(set) var activePresses: Set<FretPress> = []

    /// 방금 울린 줄의 **세기(0~1)**. 줄이 얼마나 세게 떨리고 빛나는지에 그대로 쓴다.
    /// 값이 있으면 떨리는 중, 사라지면 잦아든 것.
    ///
    /// - Note: U3의 줄 애니메이션과 H1의 햅틱이 **같은 `notePlayed` 이벤트**를 쓴다 (SPEC §5).
    @Published private(set) var stringIntensity: [Int: Double] = [:]

    /// 떨림이 잦아드는 시간. 세게 칠수록 조금 더 오래 남는다.
    private let baseFlashDuration: Double = 0.32

    private let fingeringState: FingeringStateProtocol
    private let audioEngine: GuitarAudioEngineProtocol?
    private let haptics = NotePlayedHaptics()
    private var cancellables: Set<AnyCancellable> = []
    private var flashTasks: [Int: Task<Void, Never>] = [:]

    /// 진짜 소리가 나는 기본 구성.
    convenience init() {
        let engine = GuitarAudioEngineFactory.makeDefault()
        self.init(
            fingeringState: FingeringState(audioEngine: engine),
            audioEngine: engine
        )
    }

    /// 로직 없이 화면만 먼저 개발할 때 쓰는 지름길. (ARCHITECTURE §4.1 Mock 규칙)
    ///
    /// ```swift
    /// NeckScreen(viewModel: NeckViewModel(stubChord: .am))   // 아무 데나 눌러도 Am
    /// ```
    convenience init(stubChord: GuitarChord) {
        self.init(fingeringState: MockFingeringState(stubChord: stubChord), audioEngine: nil)
    }

    /// - Parameter feedbackPublisher: 줄 떨림·햅틱을 일으킬 이벤트 스트림.
    ///   비우면 자기 `fingeringState.notePlayed`(짚기)만 먹는다. **모드 A로 조립될 때는**
    ///   세션의 합쳐진 스트림(짚기 + 자동 스트럼)을 넣어, 자동으로 긁힌 줄도 떨리고 진동한다.
    init(
        fingeringState: FingeringStateProtocol,
        audioEngine: GuitarAudioEngineProtocol?,
        feedbackPublisher: AnyPublisher<NotePlayedEvent, Never>? = nil
    ) {
        self.fingeringState = fingeringState
        self.audioEngine = audioEngine
        self.fingering = fingeringState.currentFingering

        let feedback = feedbackPublisher ?? fingeringState.notePlayed
        subscribe(feedback: feedback)
        haptics.connect(to: feedback)   // H1 — 세기별 진동
    }

    // MARK: - 화면 수명주기

    func startAudio() {
        audioEngine?.start()
    }

    func stopAudio() {
        releaseAll()
        audioEngine?.stop()
    }

    // MARK: - 입력

    /// 터치 레이어가 부른다. **지금 눌려 있는 칸 전부**를 통째로 받는다.
    func pressesChanged(_ presses: Set<FretPress>) {
        activePresses = presses
        fingeringState.pressesChanged(presses)
    }

    /// 화면을 벗어나는 등, 손을 다 뗀 것으로 쳐야 할 때.
    func releaseAll() {
        activePresses = []
        fingeringState.releaseAll()
    }

    /// 짚을 때 진동을 줄지. **모드 C에서 iPhone은 짚어도 진동 안 하고**, iPad 튕김 신호로만 진동한다.
    /// 시각(줄 떨림)은 그대로 둔다 — 짚었다는 화면 피드백은 필요하므로.
    func setHapticsEnabled(_ enabled: Bool) {
        haptics.isEnabled = enabled
    }

    // MARK: - 구독

    /// - Note: 두 퍼블리셔 모두 `@MainActor` 객체가 메인 스레드에서 보내므로 별도 홉이 필요 없다.
    private func subscribe(feedback: AnyPublisher<NotePlayedEvent, Never>) {
        fingeringState.fingeringChanged
            .sink { [weak self] fingering in
                self?.fingering = fingering
            }
            .store(in: &cancellables)

        feedback
            .sink { [weak self] event in
                self?.flash(stringIndex: event.stringIndex, velocity: event.velocity)
            }
            .store(in: &cancellables)
    }

    /// 줄 하나를 세기만큼 떨리게 한다. 같은 줄이 연달아 울리면 타이머를 다시 시작한다.
    private func flash(stringIndex: Int, velocity: UInt8) {
        flashTasks[stringIndex]?.cancel()

        let intensity = min(max(Double(velocity) / 127.0, 0.2), 1.0)
        stringIntensity[stringIndex] = intensity
        // 세게 칠수록 여운이 조금 더 길다.
        let duration = baseFlashDuration * (0.7 + 0.6 * intensity)

        flashTasks[stringIndex] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.stringIntensity[stringIndex] = nil
            self?.flashTasks[stringIndex] = nil
        }
    }
}
