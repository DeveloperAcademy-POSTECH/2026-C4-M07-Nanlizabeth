import Combine
import Foundation

/// `notePlayed` 이벤트를 구독해 **세기별 햅틱**으로 바꾸는 다리. (ROADMAP 태스크 H1)
///
/// 줄 애니메이션(U3)과 **같은 이벤트**를 먹는다 — 소리·시각·촉각이 한 신호에서 갈라진다.
/// 뷰모델은 자기 `notePlayed` 퍼블리셔만 넘기면 되고, 어느 화면인지 몰라도 된다.
///
/// ```swift
/// haptics.connect(to: fingeringState.notePlayed)   // 넥
/// haptics.connect(to: session.notePlayed)          // 모드 A/B
/// ```
///
/// ## 왜 합치나(coalesce)
///
/// 스트럼 한 번이면 6줄이 몇 ms 안에 우르르 울린다. 그때마다 진동을 쏘면 **드르륵 갈리는**
/// 느낌이 나서 오히려 싸구려다. 짧은 창 안의 이벤트는 **가장 센 것 하나로 합쳐** 한 번만 친다.
@MainActor
final class NotePlayedHaptics {
    /// 이 시간 안에 들어온 이벤트는 한 번의 진동으로 합친다.
    private let coalesceWindow: TimeInterval = 0.03

    private let decayPlayer = DecayHapticPlayer()
    private var cancellable: AnyCancellable?
    private var pendingMaxVelocity: UInt8 = 0
    private var flushTask: Task<Void, Never>?

    var isEnabled = true

    /// 구독을 건다. 이전 구독은 갈아치운다.
    func connect(to publisher: AnyPublisher<NotePlayedEvent, Never>) {
        cancellable = publisher.sink { [weak self] event in
            self?.handle(event)
        }
    }

    func disconnect() {
        cancellable = nil
        flushTask?.cancel()
        flushTask = nil
        pendingMaxVelocity = 0
    }

    private func handle(_ event: NotePlayedEvent) {
        guard isEnabled else { return }

        pendingMaxVelocity = max(pendingMaxVelocity, event.velocity)
        guard flushTask == nil else { return }   // 이미 창이 열려 있으면 합쳐지기만 한다

        flushTask = Task { [weak self, coalesceWindow] in
            try? await Task.sleep(for: .seconds(coalesceWindow))
            guard let self, !Task.isCancelled else { return }
            // 강하게 시작해 서서히 잦아드는 진동 (H2). 실기기에서만 감쇠가 느껴진다.
            self.decayPlayer.pluck(velocity: self.pendingMaxVelocity)
            self.pendingMaxVelocity = 0
            self.flushTask = nil
        }
    }
}
