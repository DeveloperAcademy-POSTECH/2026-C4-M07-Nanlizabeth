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
}

// MARK: - 단계

struct TutorialStep {
    let message: String
    /// 이 이벤트가 오면 단계 통과.
    let matches: (TutorialEvent) -> Bool
    /// 마지막 단계만 true — 건너뛰기 대신 라임 "완료" 버튼을 보인다.
    var showsCompleteButton = false
    /// 이 단계에서 넥에 목표 코드를 라임 점으로 표시할지 (있으면).
    var targetChord: GuitarChord? = nil
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

    init(store: TutorialStoreProtocol? = nil) {
        // 기본값을 인자 자리에 두면 nonisolated 문맥에서 평가돼 @MainActor와 충돌한다.
        self.store = store ?? TutorialStore()
        self.steps = Self.makeSteps()
    }

    // MARK: 조회

    var currentStep: TutorialStep? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }
    var totalSteps: Int { steps.count }
    var isRunning: Bool { phase == .running }
    var isCelebrating: Bool { phase == .celebrating }
    var isOverlayVisible: Bool { phase == .running || phase == .celebrating }

    /// 지금 넥에 표시할 목표 코드 (진행 중 + 그 단계에 목표가 있을 때).
    var neckTargetChord: GuitarChord? { isRunning ? currentStep?.targetChord : nil }

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
        if step.showsCompleteButton {
            lastActionDone = true          // 완료 버튼 활성화 (자동 진행 안 함)
        } else {
            advance()
        }
    }

    /// "이 단계 건너뛰기".
    func skip() {
        guard phase == .running else { return }
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
        if stepIndex + 1 < steps.count {
            stepIndex += 1
        } else {
            phase = .celebrating
        }
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
                matches: { if case .navigated(.strokeSelect) = $0 { return true }; return false }
            ),
            TutorialStep(
                message: "스트로크 패턴을 선택해보세요.",
                matches: { if case .patternSelected = $0 { return true }; return false }
            ),
            TutorialStep(
                message: "다시 코드를 잡아 바뀐 스트로크를 체험해보세요.",
                matches: frettedFirstChord,
                targetChord: firstChord
            ),
            TutorialStep(
                message: "아이패드에서 앱 설치 후, 버튼을 눌러 아이패드와 연결해보세요.",
                matches: { if case .connected = $0 { return true }; return false }
            ),
            TutorialStep(
                message: "이제 스트로크 모드로 이동해보세요.",
                matches: { if case .navigated(.strum) = $0 { return true }; return false }
            ),
            TutorialStep(
                message: "위아래로 줄을 튕겨 기타를 연주해보세요.",
                matches: { if case .strummed = $0 { return true }; return false },
                showsCompleteButton: true
            ),
        ]
    }
}
