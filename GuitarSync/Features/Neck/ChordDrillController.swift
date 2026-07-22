import Combine
import Foundation

/// 코드 전환 드릴을 **화면에 묶는** 컨트롤러. (docs/PLAN-chord-drill §4-4)
///
/// `ChordModeController`(모드 A)의 형제다. 하는 일은 "정답 → 다음 목표" 루프를 도는 것:
///
/// - 넥을 짚으면 → 그 운지가 목표와 맞을 때만 자동 스트럼이 소리를 낸다 (세션의 게이트가 처리).
/// - 짚은 운지가 목표와 **맞으면** → 정답 진동 + 화면 플래시 + **다음 목표로 넘어간다.**
/// - 틀린 모양은 계속 무음 — 소리를 나게 하려고 올바른 폼을 찾는 것이 곧 연습이다.
///
/// ## 왜 잠깐(settle) 기다렸다 판정하나
///
/// 코드를 만드는 **도중**엔 손가락이 하나씩 얹혀 잠깐 다른 모양을 지난다. 바로 넘겨버리면
/// 엉뚱한 타이밍에 정답 처리될 수 있다. 그래서 운지가 **잠깐 멈춘 뒤** 판정한다. 이 짧은 창 동안
/// 게이트는 열려 있으므로, 자동 스트럼이 정답 코드를 한두 번 울려 **정답 소리를 보상**으로 들려준 뒤
/// 다음 목표로 넘어간다.
@MainActor
final class ChordDrillController: ObservableObject {
    /// 넥 화면이 그대로 쓰는 뷰모델. 세션의 운지상태에 묶여 있다.
    let neck: NeckViewModel

    /// 지금 짚어야 할 목표 코드 (화면 HUD가 표시).
    @Published private(set) var currentChord: GuitarChord
    /// 진행 위치 (0-based)와 전체 개수 — 진행 표시 점에 쓴다.
    @Published private(set) var position: Int
    @Published private(set) var total: Int
    /// 방금 맞혔다는 신호. 값이 바뀔 때마다 정답 → 화면이 플래시에 쓴다.
    @Published private(set) var correctFlash: Int = 0

    private var drill: ChordDrill
    private let session: ChordDrillSession
    private let settleDelay: TimeInterval

    private var cancellable: AnyCancellable?
    private var settleTask: Task<Void, Never>?
    /// 이 운지로 이미 넘어갔으면 또 넘어가지 않는다 (같은 정답 폼을 유지하는 동안 중복 방지).
    private var lastAdvancedFingering: GuitarFingering?

    init(
        drill: ChordDrill = .moneyChords,
        engine: GuitarAudioEngineProtocol? = nil,
        clock: BeatClockProtocol? = nil,
        settleDelay: TimeInterval = 0.3
    ) {
        let engine = engine ?? GuitarAudioEngineFactory.makeDefault()
        let session = ChordDrillSession(engine: engine, clock: clock)

        self.drill = drill
        self.session = session
        self.settleDelay = settleDelay
        self.currentChord = drill.current
        self.position = drill.position
        self.total = drill.total

        // 넥은 세션의 운지상태를 공유하고, 소리는 세션의 합친 스트림으로 떨림·진동을 준다.
        self.neck = NeckViewModel(
            fingeringState: session.fingeringState,
            audioEngine: nil,
            feedbackPublisher: session.notePlayed
        )

        session.target = drill.current
        cancellable = session.fingeringState.fingeringChanged.sink { [weak self] fingering in
            self?.scheduleJudgement(for: fingering)
        }
    }

    /// 다른 노래로 갈아끼운다. 화면 진입 시 고른 노래의 진행을 넣는다.
    func load(_ newDrill: ChordDrill) {
        settleTask?.cancel()
        drill = newDrill
        session.target = newDrill.current
        currentChord = newDrill.current
        position = newDrill.position
        total = newDrill.total
        lastAdvancedFingering = nil
    }

    // MARK: - 화면 수명주기

    func start() { session.startEngine() }

    /// 자동 피킹을 켠다. 화면 진입 시 부른다. 노래마다 튕기는 순서(패턴)가 다르다.
    func play(pick: PickPattern, bpm: Double? = nil) {
        session.play(pick: pick, bpm: bpm)
    }

    func end() {
        settleTask?.cancel()
        settleTask = nil
        session.end()
    }

    // MARK: - 판정 → 진행

    private func scheduleJudgement(for fingering: GuitarFingering) {
        settleTask?.cancel()
        settleTask = Task { [weak self, settleDelay] in
            try? await Task.sleep(for: .seconds(settleDelay))
            guard let self, !Task.isCancelled else { return }
            self.judge(fingering)
        }
    }

    private func judge(_ fingering: GuitarFingering) {
        // 같은 정답 폼으로 이미 넘어갔으면 무시.
        guard fingering != lastAdvancedFingering else { return }
        guard ChordJudge.judge(played: fingering, target: drill.current) == .correct else { return }

        lastAdvancedFingering = fingering
        HapticsManager.correctChord()   // 정답 손맛
        correctFlash &+= 1              // 화면 플래시 트리거
        advance()
    }

    private func advance() {
        drill.advance()
        session.target = drill.current   // 게이트가 참조하는 목표 갱신
        currentChord = drill.current
        position = drill.position
        // 새 목표는 다시 판정 대상 — 이전 정답 폼 기억을 지운다.
        lastAdvancedFingering = nil
    }
}
