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

    /// 방금 울린 줄들. 짧게 반짝였다 사라진다.
    ///
    /// - Note: U3의 줄 애니메이션과 H1의 햅틱이 **같은 `notePlayed` 이벤트**를 쓴다.
    ///   여기 반짝임은 U2 범위의 최소 피드백이고, 본격적인 줄 떨림은 U3에서 온다.
    @Published private(set) var flashingStrings: Set<Int> = []

    /// 반짝임이 남아 있는 시간.
    private let flashDuration: Duration = .milliseconds(320)

    private let fingeringState: FingeringStateProtocol
    private let audioEngine: GuitarAudioEngineProtocol?
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

    init(fingeringState: FingeringStateProtocol, audioEngine: GuitarAudioEngineProtocol?) {
        self.fingeringState = fingeringState
        self.audioEngine = audioEngine
        self.fingering = fingeringState.currentFingering
        subscribe()
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

    // MARK: - 구독

    /// - Note: 두 퍼블리셔 모두 `@MainActor` 객체가 메인 스레드에서 보내므로 별도 홉이 필요 없다.
    private func subscribe() {
        fingeringState.fingeringChanged
            .sink { [weak self] fingering in
                self?.fingering = fingering
            }
            .store(in: &cancellables)

        fingeringState.notePlayed
            .sink { [weak self] event in
                self?.flash(stringIndex: event.stringIndex)
            }
            .store(in: &cancellables)
    }

    /// 줄 하나를 잠깐 반짝이게 한다. 같은 줄이 연달아 울리면 타이머를 다시 시작한다.
    private func flash(stringIndex: Int) {
        flashTasks[stringIndex]?.cancel()
        flashingStrings.insert(stringIndex)

        flashTasks[stringIndex] = Task { [weak self, flashDuration] in
            try? await Task.sleep(for: flashDuration)
            guard !Task.isCancelled else { return }
            self?.flashingStrings.remove(stringIndex)
            self?.flashTasks[stringIndex] = nil
        }
    }
}
