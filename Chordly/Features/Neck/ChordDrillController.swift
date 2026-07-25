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
/// ## 판정 타이밍 — settle(판정 전) + reward(넘어가기 전)
///
/// - **settle**: 코드를 만드는 **도중**엔 손가락이 하나씩 얹혀 잠깐 다른 모양을 지난다. 바로 판정하면
///   엉뚱한 타이밍에 정답 처리될 수 있어, 운지가 **잠깐 멈춘 뒤** 판정한다.
/// - **reward**: 정답을 확인하면 **바로 다음으로 넘기지 않는다.** 목표를 그대로 둔 채(게이트 열림)
///   `rewardDelay`만큼 기다려, 자동 피킹이 그 코드를 **실제로 울리게** 한 뒤 넘어간다. 즉시 넘기면
///   아직 이전 코드를 잡고 있는 손 때문에 게이트가 닫혀 **소리가 씹힌다** (피킹 한 스텝보다 판정이
///   빠르기 때문). reward 창이 그 문제를 막는다.
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
    /// 정답을 확인한 뒤, **그 코드가 실제로 울리도록 목표를 그대로 두는 시간.** 이 창이 끝나면 다음으로.
    /// 피킹 한 스텝 간격(가장 느린 패턴 ≈ 0.63초)보다 길게 둬야 최소 한 번은 소리가 난다.
    private var rewardDelay: TimeInterval

    private var cancellable: AnyCancellable?
    private var settleTask: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    /// 정답 확인 후 "코드를 들려주는 중" — 이 동안엔 판정을 멈춰 목표가 유지되게 한다.
    private var isAwaitingAdvance = false
    /// 이 운지로 이미 넘어갔으면 또 넘어가지 않는다 (같은 정답 폼을 유지하는 동안 중복 방지).
    private var lastAdvancedFingering: GuitarFingering?
    private var basePick: PickPattern = .bassStrum
    private var barPicks: [PickPattern?] = []
    private var bpmOverride: Double?
    /// 연결 합주에서는 스트로크 담당의 실제 입력이 마디를 넘긴다. 코드 담당은 소리를 내지 않는다.
    private var isExternallyAdvanced = false

    init(
        drill: ChordDrill = .moneyChords,
        engine: GuitarAudioEngineProtocol? = nil,
        clock: BeatClockProtocol? = nil,
        settleDelay: TimeInterval = 0.18,
        rewardDelay: TimeInterval = 0.75
    ) {
        let engine = engine ?? GuitarAudioEngineFactory.makeDefault()
        let session = ChordDrillSession(engine: engine, clock: clock)

        self.drill = drill
        self.session = session
        self.settleDelay = settleDelay
        self.rewardDelay = rewardDelay
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
        advanceTask?.cancel()
        retryTask?.cancel()
        isAwaitingAdvance = false
        drill = newDrill
        session.target = newDrill.current
        currentChord = newDrill.current
        position = newDrill.position
        total = newDrill.total
        lastAdvancedFingering = nil
        session.stopPlaying()
    }

    // MARK: - 화면 수명주기

    func start() { session.startEngine() }

    /// 노래의 마디별 피킹 정보를 준비한다. 실제 재생은 정답 코드를 짚은 순간 한 마디씩 시작한다.
    func play(pick: PickPattern, barPicks: [PickPattern?] = [], bpm: Double? = nil) {
        basePick = pick
        self.barPicks = barPicks
        bpmOverride = bpm
        session.stopPlaying()
    }

    func setExternallyAdvanced(_ enabled: Bool) {
        isExternallyAdvanced = enabled
        if enabled {
            session.stopPlaying()
        }
    }

    func setExternalPosition(_ index: Int) {
        guard isExternallyAdvanced,
              index != drill.position,
              let nextDrill = ChordDrill(chords: drill.chords, startIndex: index)
        else { return }

        settleTask?.cancel()
        advanceTask?.cancel()
        retryTask?.cancel()
        session.stopPlaying()
        drill = nextDrill
        session.target = nextDrill.current
        currentChord = nextDrill.current
        position = nextDrill.position
        total = nextDrill.total
        lastAdvancedFingering = nil
        isAwaitingAdvance = false
        scheduleJudgement(for: session.fingeringState.currentFingering)
    }

    func end() {
        settleTask?.cancel()
        settleTask = nil
        advanceTask?.cancel()
        advanceTask = nil
        retryTask?.cancel()
        retryTask = nil
        isAwaitingAdvance = false
        session.end()
    }

    // MARK: - 판정 → 진행

    private func scheduleJudgement(for fingering: GuitarFingering) {
        // 정답 코드를 들려주는 중이면 목표를 유지해야 하므로 판정하지 않는다.
        guard !isAwaitingAdvance else { return }
        settleTask?.cancel()

        // 목표 자리의 대부분이 완성됐고 틀린 프렛이 없으면 손을 멈추길 기다리지 않고 바로 반주한다.
        if isReadyForPlayback(fingering) {
            judge(fingering)
            return
        }

        settleTask = Task { [weak self, settleDelay] in
            try? await Task.sleep(for: .seconds(settleDelay))
            guard let self, !Task.isCancelled else { return }
            self.judge(self.session.fingeringState.currentFingering)
        }
    }

    private func judge(_ fingering: GuitarFingering) {
        guard !isAwaitingAdvance else { return }
        // 같은 정답 폼으로 이미 넘어갔으면 무시.
        guard fingering != lastAdvancedFingering else { return }
        guard isReadyForPlayback(fingering) else {
            scheduleRetryIfNeeded(for: fingering)
            return
        }

        retryTask?.cancel()
        retryTask = nil
        lastAdvancedFingering = fingering
        HapticsManager.correctChord()   // 정답 손맛
        correctFlash &+= 1              // 화면 플래시 트리거

        // 합주에서는 여기서 자동 피킹하거나 다음 마디로 넘기지 않는다.
        // 실제 소리와 진행 기준은 상대 스트로크 디바이스의 입력이다.
        if isExternallyAdvanced {
            return
        }

        let pick = currentPick
        rewardDelay = audibleRewardDelay(for: pick, bpm: bpmOverride)
        session.play(pick: pick, bpm: bpmOverride, looping: false)

        // ★ 목표를 바로 바꾸지 않는다 — 게이트를 연 채로 `rewardDelay`만큼 둬서 그 코드가 실제로
        // 울리게 한 뒤 넘어간다. (즉시 넘기면 아직 이전 코드를 잡은 손 때문에 게이트가 닫혀 소리가 씹힌다.)
        isAwaitingAdvance = true
        advanceTask?.cancel()
        advanceTask = Task { [weak self, rewardDelay] in
            try? await Task.sleep(for: .seconds(rewardDelay))
            guard let self, !Task.isCancelled else { return }
            self.advance()
        }
    }

    private func scheduleRetryIfNeeded(for fingering: GuitarFingering) {
        guard ChordJudge.judge(played: fingering, target: drill.current) != .notAttempted else { return }
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            for _ in 0..<6 {
                try? await Task.sleep(for: .seconds(0.1))
                guard let self, !Task.isCancelled, !self.isAwaitingAdvance else { return }
                let current = self.session.fingeringState.currentFingering
                if self.isReadyForPlayback(current) {
                    self.judge(current)
                    return
                }
            }
        }
    }

    private func isReadyForPlayback(_ fingering: GuitarFingering) -> Bool {
        ChordJudge.matchesForAssistedPlayback(
            played: fingering.frets,
            target: drill.current.fingering.frets
        )
    }

    private func audibleRewardDelay(for pick: PickPattern, bpm: Double?) -> TimeInterval {
        let effectiveBPM = bpm ?? pick.recommendedBPM
        let secondsPerTick = 60.0 / effectiveBPM / Double(BeatPosition.subdivisionsPerBeat)
        let loopSeconds = Double(pick.loopLengthInTicks) * secondsPerTick
        return loopSeconds + 0.08
    }

    private var currentPick: PickPattern {
        guard barPicks.indices.contains(drill.position),
              let pick = barPicks[drill.position]
        else { return basePick }
        return pick
    }

    private func advance() {
        session.stopPlaying()
        drill.advance()
        session.target = drill.current   // 게이트가 참조하는 목표 갱신
        currentChord = drill.current
        position = drill.position
        // 새 목표는 다시 판정 대상 — 이전 정답 폼 기억을 지우고 판정을 다시 연다.
        lastAdvancedFingering = nil
        isAwaitingAdvance = false
        scheduleJudgement(for: session.fingeringState.currentFingering)
    }
}
