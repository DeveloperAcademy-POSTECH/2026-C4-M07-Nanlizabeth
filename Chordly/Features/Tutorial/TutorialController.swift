import Combine
import Foundation

// MARK: - 첫 실행 저장소

/// "튜토리얼을 봤는가"를 기억한다. **앱 첫 실행에만** 온보딩 뒤에 뜨고, 완료하면 이후 스킵.
@MainActor
protocol TutorialStoreProtocol: AnyObject {
    var hasSeenTutorial: Bool { get }
    func markTutorialSeen()
}

@MainActor
final class TutorialStore: TutorialStoreProtocol {
    private enum Key { static let seen = "tutorial.hasSeen" }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var hasSeenTutorial: Bool { defaults.bool(forKey: Key.seen) }
    func markTutorialSeen() { defaults.set(true, forKey: Key.seen) }
}

/// 저장 안 하는 가짜 — 튜토리얼을 매번 다시 보며 개발할 때.
@MainActor
final class MockTutorialStore: TutorialStoreProtocol {
    private(set) var hasSeenTutorial: Bool
    init(hasSeenTutorial: Bool = false) { self.hasSeenTutorial = hasSeenTutorial }
    func markTutorialSeen() { hasSeenTutorial = true }
}

// MARK: - 이벤트 (실제 동작 검증의 재료)

/// 실제 화면에서 일어난 동작. 각 튜토리얼 단계는 자기 이벤트가 왔을 때만 넘어간다.
enum TutorialEvent: Equatable {
    case chordFretted(GuitarFingering)   // 넥에서 코드를 짚음
    case navigated(AppRoute)             // 화면 이동
    case patternSelected                 // 스트로크 패턴 고름
    case connected                       // iPad와 연결됨
    case strummed                        // 줄을 튕김
    case remoteStrummed                  // 연결된 iPad가 튕김 (스트로크 햅틱을 받음)
}

// MARK: - 단계

enum TutorialHighlightTarget: Equatable {
    case strumSelectionButton
    case strumPatternCard
    case returnToChord
    case peerButton
    case strumModeSegment
}

struct TutorialStep {
    let message: String
    /// 이 이벤트가 오면 단계 통과.
    let matches: (TutorialEvent) -> Bool
    /// 마지막 단계만 true — 건너뛰기 대신 라임 "완료" 버튼을 보인다.
    var showsCompleteButton = false
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
    enum Phase: Equatable { case idle, running, celebrating, finished }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var stepIndex = 0
    /// 마지막 단계의 동작(튕기기)을 실제로 했는가 — "완료" 버튼 활성화 조건.
    @Published private(set) var lastActionDone = false

    let steps: [TutorialStep]
    private let store: TutorialStoreProtocol

    /// 연결 단계 인덱스 (makeSteps 순서 기준). 여기서 **실제로** 연결되면 iPhone에서 직접 긁는
    /// 5·6단계 대신 "iPad를 들고 치라"는 마지막 단계로 분기한다.
    private let connectStepIndex = 4
    /// 실제 연결됐을 때만 닿는 마지막 단계 — 배열 맨 끝에 붙여 순차 진행으로는 오지 않는다.
    private var remoteStrumStepIndex: Int { steps.count - 1 }

    init(store: TutorialStoreProtocol? = nil) {
        // 기본값을 인자 자리에 두면 nonisolated 문맥에서 평가돼 @MainActor와 충돌한다.
        self.store = store ?? TutorialStore()
        self.steps = Self.makeSteps()
    }

    // MARK: 조회

    var currentStep: TutorialStep? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }
    var isRunning: Bool { phase == .running }
    var isCelebrating: Bool { phase == .celebrating }
    var isOverlayVisible: Bool { phase == .running || phase == .celebrating }

    /// 대화창 "n / 총" 표시용. 두 경로 길이가 달라서 **밟는 단계 수에 맞춘다** — 배열 인덱스를
    /// 그대로 쓰면 분기 단계(맨 끝) 때문에 단독 경로가 "7/8"에서 끝나고 연결 경로는 "5/8→8/8"로 튄다.
    /// 단독(스킵) 경로는 5·6단계까지 7단계, 실제 연결 경로는 5·6을 건너뛰어 6단계.
    private var isOnRemoteStrumStep: Bool { stepIndex == remoteStrumStepIndex }
    var displayTotalSteps: Int { isOnRemoteStrumStep ? connectStepIndex + 2 : steps.count - 1 }
    var displayStepNumber: Int { isOnRemoteStrumStep ? connectStepIndex + 2 : stepIndex + 1 }

    /// 지금 넥에 표시할 목표 코드 (진행 중 + 그 단계에 목표가 있을 때).
    var neckTargetChord: GuitarChord? { isRunning ? currentStep?.targetChord : nil }
    var highlightTarget: TutorialHighlightTarget? {
        isRunning ? currentStep?.highlightTarget : nil
    }
    /// 지금 단계가 넥에서 고른 스트로크를 자동으로 돌려 들려줘야 하는가.
    var shouldAutoPlayStrum: Bool { isRunning && (currentStep?.autoPlaysStrum ?? false) }

    // MARK: 진행

    /// 온보딩을 마친 뒤 호출. 아직 안 봤으면 튜토리얼을 시작한다.
    func startIfNeeded() {
        guard phase == .idle, !store.hasSeenTutorial else { return }
        stepIndex = 0
        lastActionDone = false
        phase = .running
    }

    /// 실제 화면이 동작을 알려온다. 지금 단계와 맞으면 넘어간다(마지막은 완료 버튼만 켠다).
    func handle(_ event: TutorialEvent) {
        guard phase == .running, let step = currentStep, step.matches(event) else { return }
        // 연결 단계에서 iPad가 **정말로** 붙으면: 짝이 생겼으니 iPhone에서 스트럼 모드로
        // 넘어가는 5·6단계는 틀린 안내다. iPad를 들고 함께 치는 마지막 단계로 곧장 분기한다.
        if case .connected = event, stepIndex == connectStepIndex {
            jumpToRemoteStrumStep()
            return
        }
        // 합주 마지막 단계에서 짝을 이룬 iPad가 실제로 튕기면 그 자리에서 바로 빵빠레로.
        // (연결만으로 완료 버튼은 이미 켜져 있어, 이 신호가 안 와도 사용자가 막히지 않는다.)
        if case .remoteStrummed = event {
            phase = .celebrating
            return
        }
        if step.showsCompleteButton {
            lastActionDone = true          // 완료 버튼 활성화 (자동 진행 안 함)
        } else {
            advance()
        }
    }

    /// "이 단계 건너뛰기". **완료 버튼 단계(마지막)는 건너뛸 수 없다** — 실제 동작으로만 끝난다.
    /// (UI가 버튼을 숨기지만, 전환 프레임의 잔여 탭이 여기로 새지 않게 호출부에도 막이를 둔다.)
    func skip() {
        guard phase == .running, currentStep?.showsCompleteButton == false else { return }
        advance()
    }

    /// 마지막 단계의 "완료" 버튼.
    func complete() {
        guard phase == .running, currentStep?.showsCompleteButton == true, lastActionDone else { return }
        phase = .celebrating
    }

    /// 빵빠레의 "시작하기" — 튜토리얼을 끝내고 다시 안 보이게 저장.
    func finish() {
        store.markTutorialSeen()
        phase = .finished
    }

    private func advance() {
        lastActionDone = false
        // 배열 맨 끝 합주 단계(remoteStrumStepIndex)는 **연결 분기로만** 닿아야 한다.
        // 순차 진행이 솔로 마지막 단계를 넘어가면 그 합주 단계로 새지 않고 축하로 끝낸다 —
        // 안 그러면 연결 안 한 사용자가 "아이패드로 튕겨달라" 단계에 갇힌다(완료 비활성).
        if stepIndex + 1 < remoteStrumStepIndex {
            stepIndex += 1
            HapticsManager.impact()        // 단계가 넘어갔다는 걸 손끝으로 약하게 알린다.
        } else {
            phase = .celebrating
        }
    }

    /// 실제 연결 시 마지막 "iPad와 함께 치기" 단계로 건너뛴다. (순차 진행이 아니라 분기)
    ///
    /// 연결 자체가 이 단계의 **동작 검증**이라 완료 버튼을 바로 켠다 — 짝이 아직 안 튕겼거나
    /// 연결이 흔들려도 사용자가 갇히지 않고, iPad가 실제로 튕기면 `handle`에서 곧장 빵빠레로 간다.
    private func jumpToRemoteStrumStep() {
        lastActionDone = true
        stepIndex = remoteStrumStepIndex
        HapticsManager.impact()            // 분기도 단계 전환이므로 동일하게 약한 피드백.
    }

    // MARK: 단계 정의

    private static func makeSteps() -> [TutorialStep] {
        // Em을 쓴다: 짚는 자리(A·D현 2프렛)가 넥 위쪽이라 하단 대화창에 안 가리고, 2손가락이라 쉽다.
        let firstChord = GuitarChord.em
        func frettedFirstChord(_ event: TutorialEvent) -> Bool {
            if case let .chordFretted(f) = event {
                return ChordJudge.matches(played: f.frets, target: firstChord.fingering.frets)
            }
            return false
        }
        return [
            TutorialStep(
                message: "표시된 줄을 눌러 첫 코드를 완성해보세요.",
                matches: frettedFirstChord,
                targetChord: firstChord
            ),
            TutorialStep(
                message: "스트로크 패턴 선택 페이지에 진입해보세요.",
                matches: { if case .navigated(.strokeSelect) = $0 { return true }; return false },
                highlightTarget: .strumSelectionButton
            ),
            TutorialStep(
                message: "빛나는 카드를 눌러 스트로크 패턴을 선택해보세요.",
                matches: { if case .patternSelected = $0 { return true }; return false },
                highlightTarget: .strumPatternCard
            ),
            TutorialStep(
                message: "오른쪽 위 체크 버튼으로 돌아가 코드를 잡고, 고른 스트로크를 들어보세요.",
                matches: frettedFirstChord,
                targetChord: firstChord,
                highlightTarget: .returnToChord,
                autoPlaysStrum: true
            ),
            TutorialStep(
                message: "아이패드가 있다면 버튼을 눌러 연결해보세요. 없으면 건너뛰어도 괜찮아요.",
                matches: { if case .connected = $0 { return true }; return false },
                highlightTarget: .peerButton
            ),
            TutorialStep(
                message: "이제 스트로크 모드로 이동해보세요.",
                matches: { if case .navigated(.strum) = $0 { return true }; return false },
                highlightTarget: .strumModeSegment
            ),
            TutorialStep(
                message: "위아래로 줄을 튕겨 기타를 연주해보세요.",
                matches: { if case .strummed = $0 { return true }; return false },
                showsCompleteButton: true
            ),
            // 연결됐을 때만 분기로 닿는 마지막 단계 (순차로는 앞 단계에서 celebrating으로 끝나 오지 않는다).
            // 완료 버튼은 연결과 동시에 켜지고(막힘 방지), 짝을 이룬 iPad가 실제로 튕기면
            // remoteStrummed로 그 자리에서 바로 축하로 넘어간다.
            TutorialStep(
                message: "연결됐어요! 이제 아이패드로 줄을 튕겨 함께 연주해보세요.",
                matches: { if case .remoteStrummed = $0 { return true }; return false },
                showsCompleteButton: true
            ),
        ]
    }
}
