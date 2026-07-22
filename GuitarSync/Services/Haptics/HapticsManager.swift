import UIKit

/// 손끝 진동 피드백. (ROADMAP 태스크 H1 · SPEC §5)
///
/// - Note: 지금은 `UIImpactFeedbackGenerator` 기반이라 **한 번 툭** 치는 진동만 된다.
///   "튕긴 뒤 서서히 잦아드는" 감쇠 진동은 Core Haptics가 필요하다 → 태스크 H2에서 승격.
enum HapticsManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func mediumImpact() {
        impact(.medium)
    }

    /// 줄을 튕긴 **세기(0~127)에 비례**한 진동. (SPEC §5.1 발음 햅틱)
    ///
    /// 세기를 강도(0~1)로 환산하고, 무게감은 스타일로도 나눈다 —
    /// `UIImpactFeedbackGenerator`는 강도를 미세하게 반영하지만 스타일 차이가 더 크게 느껴진다.
    static func pluck(velocity: UInt8) {
        // 전체적으로 세게 느껴지도록 강도에 바닥(0.6)을 둔다 — 약한 튕김도 확실히 전해지게.
        let normalized = min(max(Double(velocity) / 127.0, 0), 1)
        let intensity = 0.6 + 0.4 * normalized

        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch velocity {
        case ..<70: style = .medium
        default: style = .heavy
        }

        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: CGFloat(intensity))
    }

    /// 목표와 다른 코드를 짚었을 때의 "아니야" 진동. (SPEC §5.2 판정 햅틱)
    ///
    /// 발음 햅틱(`pluck`)과 확실히 구분되도록 **오류 알림 패턴**을 쓴다 — 세게 한 번이 아니라
    /// 틀렸다는 신호로 읽히는 두 번 진동.
    static func wrongChord() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// 목표 코드를 정확히 짚었을 때의 "맞았어" 진동. (docs/PLAN-chord-drill §4-6)
    ///
    /// 오답(`wrongChord`)과 반대로 **성공 알림 패턴**을 써서, 코드 드릴에서 정답으로
    /// 넘어가는 순간을 손끝으로 확인시켜 준다.
    static func correctChord() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
