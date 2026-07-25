import Combine
import Foundation

// MARK: - 첫 실행 저장소

/// "튜토리얼을 봤는가"를 기억한다. **앱 첫 실행에만** 온보딩 뒤에 뜨고, 완료하면 이후 스킵.
@MainActor
protocol TutorialStoreProtocol: AnyObject {
    var hasSeenTutorial: Bool { get }
    var hasSeenConnectedSongTutorial: Bool { get }
    func markTutorialSeen()
    func markConnectedSongTutorialSeen()
}

@MainActor
final class TutorialStore: TutorialStoreProtocol {
    private enum Key {
        static let seen = "tutorial.hasSeen"
        static let connectedSongSeen = "tutorial.connectedSong.hasSeen"
    }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var hasSeenTutorial: Bool { defaults.bool(forKey: Key.seen) }
    var hasSeenConnectedSongTutorial: Bool { defaults.bool(forKey: Key.connectedSongSeen) }
    func markTutorialSeen() { defaults.set(true, forKey: Key.seen) }
    func markConnectedSongTutorialSeen() { defaults.set(true, forKey: Key.connectedSongSeen) }
}

/// 저장 안 하는 가짜 — 튜토리얼을 매번 다시 보며 개발할 때.
@MainActor
final class MockTutorialStore: TutorialStoreProtocol {
    private(set) var hasSeenTutorial: Bool
    private(set) var hasSeenConnectedSongTutorial: Bool
    init(
        hasSeenTutorial: Bool = false,
        hasSeenConnectedSongTutorial: Bool = false
    ) {
        self.hasSeenTutorial = hasSeenTutorial
        self.hasSeenConnectedSongTutorial = hasSeenConnectedSongTutorial
    }
    func markTutorialSeen() { hasSeenTutorial = true }
    func markConnectedSongTutorialSeen() { hasSeenConnectedSongTutorial = true }
}

// MARK: - 이벤트 (실제 동작 검증의 재료)

/// 실제 화면에서 일어난 동작. 각 튜토리얼 단계는 자기 이벤트가 왔을 때만 넘어간다.
enum TutorialEvent: Equatable {
    case chordFretted(GuitarFingering)   // 넥에서 코드를 짚음
    case navigated(AppRoute)             // 화면 이동
    case neckLayoutChanged               // 손 크기에 맞는 넥 크기를 선택함
    case patternSelected                 // 스트로크 패턴 고름
    case bpmOpened                       // BPM 팝오버를 엶
    case bpmCommitted(Int)               // 숫자패드로 BPM 입력을 확정함
    case playbackStarted                 // 자동 스트로크 재생을 시작함
    case automaticStrum(GuitarFingering) // 현재 운지로 자동 스트로크 한 획이 재생됨
    case peerButtonTapped                // 상단 멀티피어 버튼을 누름
    case peerSelected(String)            // 발견 목록에서 기기를 선택함
    case connected                       // iPad와 연결됨
    case songSelected                    // 연결 합주에서 함께 연주할 곡을 고름
    case strummed                        // 줄을 튕김
    case remoteStrummed                  // 연결된 iPad가 튕김 (스트로크 햅틱을 받음)
}

// MARK: - 단계

enum TutorialHighlightTarget: Equatable {
    case neckSizeButton
    case strumSelectionButton
    case strumPatternCard
    case returnToChord
    case bpmButton
    case bpmNumber
    case playButton
    case songSelectionButton
    case peerButton
    case strumModeSegment
}

enum TutorialFlow {
    case iPhone
    case iPadConnection
    case connectedSong
}

struct TutorialStep {
    let message: String
    /// 이 이벤트가 오면 단계 통과.
    let matches: (TutorialEvent) -> Bool
    /// 이벤트를 수행한 뒤 안내 박스 안 버튼을 눌러야 넘어가는 단계.
    var actionButtonTitle: String? = nil
    var actionAdvances = false
    var actionStartsEnabled = false
    var allowsSkip = true
    /// 같은 이벤트를 몇 번 성공해야 통과하는가.
    var requiredMatchCount = 1
    /// 이 단계를 마치면 바로 축하 화면을 띄운다.
    var celebratesOnMatch = false
    /// 이 단계를 마치면 노래 목록에서 마지막 안내를 띄운다.
    var showsEnjoyPromptOnMatch = false
    /// 정답 운지를 완성했을 때 화면 테두리 성공 효과를 켠다.
    var showsSuccessBorderOnMatch = false
    /// 정답 코드를 처음 완성했을 때 운지 영역에 작은 축하 효과를 띄운다.
    var showsChordConfettiOnMatch = false
    /// 연결 완료처럼 이 단계에서 튜토리얼을 바로 끝낸다.
    var finishesOnMatch = false
    /// 이 단계에서 넥에 목표 코드를 라임 점으로 표시할지 (있으면).
    var targetChord: GuitarChord? = nil
    /// 지금 눌러야 할 화면 컨트롤. 해당 뷰가 라임 펄스로 표시한다.
    var highlightTarget: TutorialHighlightTarget? = nil
    /// 이 단계에서 넥에 들어오면 **자동재생을 바로 켠다** — 고른 스트로크가 계속 돌며 들리게.
    /// (안 켜면 짚을 때 개별 발음만 한 번 나고 스트로크를 체험할 수 없다.)
    var autoPlaysStrum = false
}

// MARK: - 컨트롤러

/// 온보딩 뒤 **첫 실행 튜토리얼**을 진행한다. 실제 화면 위에 대화창을 얹고, 안내 동작을 실제로
/// 했는지 이벤트로 **검증**하며 단계를 넘긴다. 건너뛰기·완료·빵빠레까지. (Figma 794-2067 · 815-6252)
@MainActor
final class TutorialController: ObservableObject {
    enum Phase: Equatable { case idle, running, celebrating, readyToEnjoy, finished }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var stepIndex = 0
    /// 버튼으로 확정하는 단계의 선행 동작을 실제로 했는가.
    @Published private(set) var lastActionDone = false
    @Published private(set) var matchedActionCount = 0
    @Published private(set) var showsSuccessBorder = false
    @Published private(set) var showsChordConfetti = false
    @Published private(set) var shouldOfferConnectionTutorial = false

    @Published private(set) var steps: [TutorialStep]
    private(set) var flow: TutorialFlow
    private let store: TutorialStoreProtocol
    private var awaitsIPhoneTutorialAfterConnection = false

    init(store: TutorialStoreProtocol? = nil) {
        // 기본값을 인자 자리에 두면 nonisolated 문맥에서 평가돼 @MainActor와 충돌한다.
        self.store = store ?? TutorialStore()
        self.flow = .iPhone
        self.steps = Self.makeSteps()
    }

    // MARK: 조회

    var currentStep: TutorialStep? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }
    var isRunning: Bool { phase == .running }
    var isCelebrating: Bool { phase == .celebrating }
    var isReadyToEnjoy: Bool { phase == .readyToEnjoy }
    var isOverlayVisible: Bool {
        phase == .running || phase == .celebrating || phase == .readyToEnjoy
    }

    var displayTotalSteps: Int { steps.count }
    var displayStepNumber: Int { stepIndex + 1 }
    var displayMessage: String {
        guard let step = currentStep else { return "" }
        guard step.requiredMatchCount > 1 else { return step.message }
        return "\(step.message)  \(matchedActionCount) / \(step.requiredMatchCount)"
    }
    var celebrationButtonTitle: String { flow == .iPhone ? "다음" : "시작하기" }
    var isConnectionTutorial: Bool { flow == .iPadConnection && isOverlayVisible }
    var keepsBPMKeypadClear: Bool {
        flow == .iPhone && isRunning && stepIndex == 5
    }
    /// E 코드 학습의 9~10단계는 뒤집힌 휴대폰 위에서 읽으므로 안내 박스도 함께 뒤집는다.
    var rotatesDialogForUpsideDownViewing: Bool {
        flow == .iPhone && isRunning && (8...9).contains(stepIndex)
    }
    /// E 코드 운지를 처음 보여주는 8단계에서 숫자의 의미를 함께 설명한다.
    var showsFingerNumberLegend: Bool {
        flow == .iPhone && isRunning && stepIndex == 7
    }

    /// 지금 넥에 표시할 목표 코드 (진행 중 + 그 단계에 목표가 있을 때).
    var neckTargetChord: GuitarChord? { isRunning ? currentStep?.targetChord : nil }
    var targetGuideRotationDegrees: Double { neckTargetChord == nil ? 0 : 180 }
    var highlightTarget: TutorialHighlightTarget? {
        if shouldOfferConnectionTutorial { return .peerButton }
        return isRunning ? currentStep?.highlightTarget : nil
    }
    /// 지금 단계가 넥에서 고른 스트로크를 자동으로 돌려 들려줘야 하는가.
    var shouldAutoPlayStrum: Bool { isRunning && (currentStep?.autoPlaysStrum ?? false) }

    // MARK: 진행

    /// 온보딩 마지막 선택에 맞는 튜토리얼을 준비한다. 실제 시작은 화면 전환 뒤 `startIfNeeded()`가 한다.
    func prepare(for flow: TutorialFlow) {
        guard phase == .idle else { return }
        self.flow = flow
        steps = flow == .iPhone ? Self.makeSteps() : Self.makeIPadConnectionSteps()
        stepIndex = 0
        lastActionDone = false
        matchedActionCount = 0
        showsSuccessBorder = false
        showsChordConfetti = false
        shouldOfferConnectionTutorial = false
    }

    /// 온보딩을 마친 뒤 호출. 아직 안 봤으면 튜토리얼을 시작한다.
    func startIfNeeded() {
        guard phase == .idle, !store.hasSeenTutorial else { return }
        stepIndex = 0
        lastActionDone = false
        matchedActionCount = 0
        showsSuccessBorder = false
        showsChordConfetti = false
        lastActionDone = currentStep?.actionStartsEnabled ?? false
        phase = .running
    }

    /// 일반 튜토리얼 종료 뒤 또는 온보딩의 아이패드 연결 분기에서 같은 연결 튜토리얼을 시작한다.
    func startConnectionTutorial() {
        flow = .iPadConnection
        steps = Self.makeIPadConnectionSteps()
        stepIndex = 0
        matchedActionCount = 0
        lastActionDone = steps.first?.actionStartsEnabled ?? false
        showsSuccessBorder = false
        showsChordConfetti = false
        shouldOfferConnectionTutorial = false
        phase = .running
    }

    /// 연결 튜토리얼을 먼저 마친 iPhone이 연결을 끊고 코드 화면으로 돌아왔을 때
    /// 아직 배우지 않은 기본 iPhone 튜토리얼을 이어서 시작한다.
    func startIPhoneTutorialAfterConnectionIfNeeded() {
        guard awaitsIPhoneTutorialAfterConnection,
              phase == .finished,
              !store.hasSeenTutorial
        else { return }

        awaitsIPhoneTutorialAfterConnection = false
        flow = .iPhone
        steps = Self.makeSteps()
        stepIndex = 0
        matchedActionCount = 0
        lastActionDone = steps.first?.actionStartsEnabled ?? false
        showsSuccessBorder = false
        showsChordConfetti = false
        shouldOfferConnectionTutorial = false
        phase = .running
    }

    /// 연결을 요청해 코드 역할을 맡은 디바이스에 최초 한 번만 곡 선택 방법을 안내한다.
    func startConnectedSongTutorialIfNeeded(isRequester: Bool) {
        guard isRequester,
              !store.hasSeenConnectedSongTutorial,
              phase == .idle || phase == .finished
        else { return }

        flow = .connectedSong
        steps = Self.makeConnectedSongSteps()
        stepIndex = 0
        matchedActionCount = 0
        lastActionDone = false
        showsSuccessBorder = false
        showsChordConfetti = false
        shouldOfferConnectionTutorial = false
        phase = .running
    }

    /// 실제 화면이 동작을 알려온다. 현재 단계와 맞는 동작만 횟수에 반영한다.
    func handle(_ event: TutorialEvent) {
        guard phase == .running, let step = currentStep, step.matches(event) else { return }

        matchedActionCount += 1
        if step.showsSuccessBorderOnMatch {
            showsSuccessBorder = true
        }
        if step.showsChordConfettiOnMatch {
            showChordConfettiBriefly()
        }
        guard matchedActionCount >= step.requiredMatchCount else { return }

        if step.actionButtonTitle != nil {
            lastActionDone = true
            return
        }
        if step.celebratesOnMatch {
            showsSuccessBorder = false
            phase = .celebrating
            return
        }
        if step.showsEnjoyPromptOnMatch {
            phase = .readyToEnjoy
            return
        }
        if step.finishesOnMatch {
            finish()
            return
        }
        advance()
    }

    func skip() {
        guard phase == .running, currentStep?.allowsSkip == true else { return }
        advance()
    }

    /// 안내 박스의 `다음`/`완료` 버튼.
    func confirmCurrentStep() {
        guard phase == .running,
              let step = currentStep,
              step.actionButtonTitle != nil,
              lastActionDone
        else { return }

        if step.actionAdvances {
            advance()
        } else {
            phase = .celebrating
        }
    }

    /// 축하 화면 뒤 아이폰은 노래 버튼 안내로, 아이패드 연결 흐름은 종료로 간다.
    func continueAfterCelebration() {
        guard phase == .celebrating else { return }
        guard flow == .iPhone, !steps.isEmpty else {
            finish()
            return
        }
        stepIndex = steps.count - 1
        matchedActionCount = 0
        lastActionDone = false
        phase = .running
    }

    /// 빵빠레의 "시작하기" — 튜토리얼을 끝내고 다시 안 보이게 저장.
    func finish() {
        showsSuccessBorder = false
        showsChordConfetti = false

        if flow == .iPadConnection {
            awaitsIPhoneTutorialAfterConnection = !store.hasSeenTutorial
            phase = .finished
            return
        }

        if flow == .connectedSong {
            store.markConnectedSongTutorialSeen()
            phase = .finished
            return
        }

        store.markTutorialSeen()
        shouldOfferConnectionTutorial = true
        phase = .finished
    }

    func endConnectionTutorial() {
        guard flow == .iPadConnection else { return }
        showsSuccessBorder = false
        showsChordConfetti = false
        phase = .finished
    }

    private func advance() {
        lastActionDone = false
        matchedActionCount = 0
        if stepIndex + 1 < steps.count {
            stepIndex += 1
            lastActionDone = currentStep?.actionStartsEnabled ?? false
            HapticsManager.impact()
        } else {
            phase = .celebrating
        }
    }

    private func showChordConfettiBriefly() {
        showsChordConfetti = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            self?.showsChordConfetti = false
        }
    }

    // MARK: 단계 정의

    private static func makeSteps() -> [TutorialStep] {
        let tutorialChord = GuitarChord.e
        func frettedTutorialChord(_ event: TutorialEvent) -> Bool {
            if case let .chordFretted(f) = event {
                return ChordJudge.matches(played: f.frets, target: tutorialChord.fingering.frets)
            }
            return false
        }
        func strummedTutorialChord(_ event: TutorialEvent) -> Bool {
            if case let .automaticStrum(f) = event {
                return ChordJudge.matches(played: f.frets, target: tutorialChord.fingering.frets)
            }
            return false
        }

        return [
            TutorialStep(
                message: "왼쪽 위 크기 버튼을 눌러 화면을 줄이고 늘려보세요. 손에 맞는 크기를 고른 뒤 다음을 눌러주세요.",
                matches: { if case .neckLayoutChanged = $0 { return true }; return false },
                actionButtonTitle: "다음",
                actionAdvances: true,
                highlightTarget: .neckSizeButton
            ),
            TutorialStep(
                message: "상단의 스트로크 선택 버튼을 눌러주세요.",
                matches: { if case .navigated(.strokeSelect) = $0 { return true }; return false },
                highlightTarget: .strumSelectionButton
            ),
            TutorialStep(
                message: "화면에 표시된 스트로크를 눌러보세요.",
                matches: { if case .patternSelected = $0 { return true }; return false },
                highlightTarget: .strumPatternCard
            ),
            TutorialStep(
                message: "오른쪽 위 체크 버튼을 눌러 코드 화면으로 돌아가세요.",
                matches: { if case .navigated(.neck) = $0 { return true }; return false },
                highlightTarget: .returnToChord
            ),
            TutorialStep(
                message: "BPM 버튼을 눌러 속도를 설정해볼게요.",
                matches: { if case .bpmOpened = $0 { return true }; return false },
                highlightTarget: .bpmButton
            ),
            TutorialStep(
                message: "숫자 칸을 누르고 60을 입력한 뒤 숫자패드의 완료를 눌러주세요.",
                matches: { if case .bpmCommitted(60) = $0 { return true }; return false },
                highlightTarget: .bpmNumber
            ),
            TutorialStep(
                message: "재생 버튼을 눌러 스트로크를 시작하세요.",
                matches: { if case .playbackStarted = $0 { return true }; return false },
                highlightTarget: .playButton
            ),
            TutorialStep(
                message: "휴대폰을 뒤집어 숫자가 정방향으로 보이게 해주세요.\n왼손으로 화면의 번호대로 E 코드를 짚으세요. 숫자는 검지부터 새끼손가락까지의 번호예요.",
                matches: frettedTutorialChord,
                showsChordConfettiOnMatch: true,
                targetChord: tutorialChord
            ),
            TutorialStep(
                message: "축하합니다. 벌써 E 코드를 배웠어요!",
                matches: { _ in false },
                actionButtonTitle: "다음",
                actionAdvances: true,
                actionStartsEnabled: true,
                targetChord: tutorialChord
            ),
            TutorialStep(
                message: "E 코드를 유지한 채 스트로크 4번을 들어보세요.",
                matches: strummedTutorialChord,
                requiredMatchCount: 4,
                celebratesOnMatch: true,
                showsSuccessBorderOnMatch: true,
                targetChord: tutorialChord
            ),
            TutorialStep(
                message: "이제 음표 버튼을 눌러 노래 목록으로 들어가보세요.",
                matches: { if case .navigated(.chordDrillSongSelect) = $0 { return true }; return false },
                showsEnjoyPromptOnMatch: true,
                highlightTarget: .songSelectionButton
            ),
        ]
    }

    private static func makeIPadConnectionSteps() -> [TutorialStep] {
        [
            TutorialStep(
                message: "다른 디바이스에도 앱을 다운로드 받고 실행해주세요.",
                matches: { _ in false },
                actionButtonTitle: "다음",
                actionAdvances: true,
                actionStartsEnabled: true
            ),
            TutorialStep(
                message: "디바이스를 가까이 가지고 있거나 같은 와이파이를 사용해주세요.",
                matches: { _ in false },
                actionButtonTitle: "다음",
                actionAdvances: true,
                actionStartsEnabled: true
            ),
            TutorialStep(
                message: "상단의 아이패드 플러스 아이콘을 눌러주세요.",
                matches: { if case .peerButtonTapped = $0 { return true }; return false },
                highlightTarget: .peerButton
            ),
            TutorialStep(
                message: "목록에서 연결할 디바이스 이름을 찾아 눌러주세요.",
                matches: { if case .peerSelected = $0 { return true }; return false }
            ),
            TutorialStep(
                message: "연결을 하고 있어요. 두 디바이스를 가까이 유지해주세요.",
                matches: { if case .connected = $0 { return true }; return false },
                finishesOnMatch: true
            ),
        ]
    }

    private static func makeConnectedSongSteps() -> [TutorialStep] {
        [
            TutorialStep(
                message: "두 디바이스가 함께 연주할 곡을 골라볼게요. 음표 버튼을 눌러 노래 목록을 열어주세요.",
                matches: { if case .navigated(.chordDrillSongSelect) = $0 { return true }; return false },
                highlightTarget: .songSelectionButton
            ),
            TutorialStep(
                message: "연주할 노래를 하나 골라주세요. 상대 디바이스에도 같은 곡이 바로 열려요.",
                matches: { if case .songSelected = $0 { return true }; return false },
                finishesOnMatch: true
            ),
        ]
    }
}
