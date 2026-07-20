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
        let normalized = min(max(Double(velocity) / 127.0, 0), 1)

        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch velocity {
        case ..<70: style = .light
        case 70..<100: style = .medium
        default: style = .heavy
        }

        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: CGFloat(normalized))
    }

    /// 목표와 다른 코드를 짚었을 때의 "아니야" 진동. (SPEC §5.2 판정 햅틱)
    ///
    /// 발음 햅틱(`pluck`)과 확실히 구분되도록 **오류 알림 패턴**을 쓴다 — 세게 한 번이 아니라
    /// 틀렸다는 신호로 읽히는 두 번 진동.
    static func wrongChord() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
