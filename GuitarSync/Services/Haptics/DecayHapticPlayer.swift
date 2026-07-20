import Foundation
#if canImport(CoreHaptics)
import CoreHaptics
#endif

/// 줄을 튕긴 순간 **강하게 → 서서히 잦아드는** 진동. (ROADMAP 태스크 H2 · SPEC §5.1 감쇠 햅틱)
///
/// ## 왜 Core Haptics인가
///
/// `UIImpactFeedbackGenerator`는 **툭 한 번**만 친다 — "튕긴 뒤 서서히 옅어지는" 진동은 못 만든다.
/// 진짜 기타 줄처럼 잦아들게 하려면 **이어지는 진동**(`CHHapticEvent .continuous`)에
/// **감쇠 곡선**(`CHHapticParameterCurve`)을 씌워야 한다 — 그게 이 클래스가 하는 일이다.
///
/// ## 폴백
///
/// Core Haptics를 지원하지 않는 기기·시뮬레이터에서는 조용히 `UIImpactFeedbackGenerator`로 내려간다.
/// **시뮬레이터에서는 진동 자체가 안 나므로**, 감쇠 여부는 실기기에서만 확인된다.
@MainActor
final class DecayHapticPlayer {
    /// 튕긴 진동이 잦아드는 데 걸리는 시간. 세게 칠수록 길다.
    private let baseDuration: TimeInterval = 0.5

    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
    #endif

    init() {
        prepareEngine()
    }

    /// 세기(0~127)에 비례한 감쇠 진동을 한 번 재생한다.
    func pluck(velocity: UInt8) {
        let intensity = Float(min(max(Double(velocity) / 127.0, 0), 1))

        #if canImport(CoreHaptics)
        if supportsHaptics, playDecay(intensity: intensity) {
            return
        }
        #endif
        // 폴백: 감쇠는 못 주지만 세기는 반영.
        HapticsManager.pluck(velocity: velocity)
    }

    // MARK: - Core Haptics

    private func prepareEngine() {
        #if canImport(CoreHaptics)
        guard supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            // 시스템이 엔진을 멈추면(앱 백그라운드 등) 다음 재생 때 되살릴 수 있게 재시작 핸들러를 둔다.
            engine.stoppedHandler = { _ in }
            engine.resetHandler = { [weak self] in try? self?.engine?.start() }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
        #endif
    }

    #if canImport(CoreHaptics)
    /// 감쇠 진동을 재생한다. 성공하면 `true`.
    private func playDecay(intensity: Float) -> Bool {
        guard let engine else { return false }

        // 세게 칠수록 강도가 높고 여운도 길다. 최소치를 둬서 약한 튕김도 느껴지게 한다.
        let peak = 0.55 + 0.45 * intensity            // 0.55~1.0 — 전체적으로 세게
        let sharpness = 0.4 + 0.4 * intensity
        let duration = baseDuration * TimeInterval(0.6 + 0.8 * intensity)

        // 강도를 시작 peak → 끝 0으로 끌어내리는 곡선 = "잦아드는" 느낌.
        let decayCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 1.0),
                .init(relativeTime: duration * 0.25, value: 0.6),
                .init(relativeTime: duration, value: 0.0),
            ],
            relativeTime: 0
        )

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: peak),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: duration
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameterCurves: [decayCurve])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }
    #endif
}
