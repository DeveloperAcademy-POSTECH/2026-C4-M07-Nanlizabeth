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
/// ## 엔진이 멈춰도 되살린다 (재연결 후에도 정상)
///
/// `CHHapticEngine`은 앱이 백그라운드로 가거나 오디오 세션이 흔들리면(전화·기기 연결 변화 등)
/// **조용히 멈춘다.** 안 되살리면 다음부터 감쇠 진동이 안 나고 약한 폴백(툭 한 번)만 남는다 —
/// "연결 끊었다 다시 하면 진동이 한 번 약하게만 오던" 증상의 원인. 그래서 **재생 직전마다 엔진이
/// 돌고 있는지 확인해 필요하면 켜고**, 그래도 실패하면 한 번 되살려 재시도한다.
///
/// ## 폴백
///
/// Core Haptics 미지원 기기·시뮬레이터에서는 조용히 `UIImpactFeedbackGenerator`로 내려간다.
/// **시뮬레이터에서는 진동 자체가 안 나므로**, 감쇠 여부는 실기기에서만 확인된다.
@MainActor
final class DecayHapticPlayer {
    /// 튕긴 진동이 잦아드는 데 걸리는 시간. 세게 칠수록 길다.
    private let baseDuration: TimeInterval = 0.5

    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    /// 엔진이 지금 돌고 있다고 아는 값. 핸들러가 갱신하지만, 재생 실패 시 실제와 맞춰 되살린다.
    private var isRunning = false
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
            // 쉴 때 스스로 꺼지게 두고, 재생 직전에 다시 켠다 (전력 절약 + 항상 최신 상태).
            engine.isAutoShutdownEnabled = true
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.isRunning = false }
            }
            // 미디어 서비스 리셋 등으로 엔진이 초기화되면 곧바로 되살린다.
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.isRunning = false
                    _ = self?.ensureStarted()
                }
            }
            self.engine = engine
            isRunning = false   // 첫 재생 때 켠다 (lazy)
        } catch {
            engine = nil
        }
        #endif
    }

    #if canImport(CoreHaptics)
    /// 엔진이 돌고 있게 만든다. 성공하면 `true`.
    private func ensureStarted() -> Bool {
        guard let engine else { return false }
        if isRunning { return true }
        do {
            try engine.start()
            isRunning = true
            return true
        } catch {
            return false
        }
    }

    /// 감쇠 진동을 재생한다. 성공하면 `true`.
    private func playDecay(intensity: Float) -> Bool {
        guard let engine, ensureStarted() else { return false }

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

        guard let pattern = try? CHHapticPattern(events: [event], parameterCurves: [decayCurve]) else {
            return false
        }

        if playOnce(pattern: pattern, on: engine) { return true }

        // 엔진이 (핸들러가 미처 알리기 전에) 조용히 멈춰 있었을 수 있다 — 한 번 되살려 재시도.
        isRunning = false
        guard ensureStarted() else { return false }
        return playOnce(pattern: pattern, on: engine)
    }

    private func playOnce(pattern: CHHapticPattern, on engine: CHHapticEngine) -> Bool {
        do {
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }
    #endif
}
