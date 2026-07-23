import Combine
import Foundation

/// 목표 코드와 다른 운지를 짚으면 진동으로 알려준다. (ROADMAP 태스크 H3 · SPEC §5.2)
///
/// ## 언제 켜지나 (SPEC §8 미결정 — 그래서 플래그로 열어둠)
///
/// **목표 코드가 있어야 판정할 수 있다.** 모드 A엔 정답이 없고, 모드 B는 자동 진행이 목표를
/// 알려준다. 그래서 이 컨트롤러는 `target`이 있을 때만 동작하고, 어느 모드에서 켤지는
/// 호출부가 `target`을 넣느냐 마느냐로 정한다 (SPEC §8 판정 햅틱 범위 결정 대기).
///
/// ## 왜 지연(debounce)하나
///
/// 코드를 만드는 **도중**엔 손가락이 하나씩 얹혀 잠깐 틀린 모양을 지난다. 그때마다 진동하면
/// 짚을 때마다 드르륵거린다. 그래서 운지가 **잠깐 멈춘 뒤**에 판정하고, **틀린 모양 하나당 한 번만**
/// 울린다 (같은 틀린 코드를 유지하는 동안 반복 안 함).
@MainActor
final class ChordJudgmentController {
    /// 지금 맞혀야 할 코드. `nil`이면 판정 안 함 (모드 A 등).
    var target: GuitarChord? {
        didSet { lastJudgedFingering = nil }   // 목표가 바뀌면 다시 판정
    }

    /// 켜고 끄기. 접근성 설정 등에서 끌 수 있게.
    var isEnabled = true

    /// 운지가 멈췄다고 볼 때까지의 시간.
    private let settleDelay: TimeInterval

    /// 판정이 틀렸을 때 실제로 할 일. 테스트에서 스파이로 갈아끼운다.
    private let onWrong: () -> Void

    private var cancellable: AnyCancellable?
    private var settleTask: Task<Void, Never>?
    /// 마지막으로 판정한 운지 — 같은 걸 또 울리지 않으려고 기억한다.
    private var lastJudgedFingering: GuitarFingering?

    init(settleDelay: TimeInterval = 0.4, onWrong: @escaping () -> Void = { HapticsManager.wrongChord() }) {
        self.settleDelay = settleDelay
        self.onWrong = onWrong
    }

    /// 운지 변화 스트림에 물린다. 보통 `FingeringState.fingeringChanged`.
    func connect(to fingeringChanged: AnyPublisher<GuitarFingering, Never>) {
        cancellable = fingeringChanged.sink { [weak self] fingering in
            self?.scheduleJudgement(for: fingering)
        }
    }

    func disconnect() {
        cancellable = nil
        settleTask?.cancel()
        settleTask = nil
    }

    private func scheduleJudgement(for fingering: GuitarFingering) {
        settleTask?.cancel()
        settleTask = Task { [weak self, settleDelay] in
            try? await Task.sleep(for: .seconds(settleDelay))
            guard let self, !Task.isCancelled else { return }
            self.judgeNow(fingering)
        }
    }

    /// 지연 없이 즉시 판정 (테스트·즉시 반응용).
    func judgeNow(_ fingering: GuitarFingering) {
        guard isEnabled, let target else { return }
        // 같은 운지를 이미 판정했으면 다시 울리지 않는다.
        guard fingering != lastJudgedFingering else { return }

        switch ChordJudge.judge(played: fingering, target: target) {
        case .incorrect:
            lastJudgedFingering = fingering
            onWrong()
        case .correct:
            // 맞았으면 조용히. 다음에 틀리면 다시 울리도록 기록만 한다.
            lastJudgedFingering = fingering
        case .notAttempted:
            // 아직 만드는 중 — 기록도 안 남겨 다음 판정을 막지 않는다.
            break
        }
    }
}
