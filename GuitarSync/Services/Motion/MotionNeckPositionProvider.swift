import Combine
import CoreMotion
import Foundation

/// 📱 **코어모션 버전** — 기기를 기울여 넥 포지션을 옮긴다. 실제로 손을 넥 위아래로 옮기는
/// 감각의 근사. (docs/PLAN-neck-position · A/B 상대편)
///
/// ## 좋은 기타 경험을 위해 고려한 것들
/// - **떨림 억제:** 손 떨림이 그대로 포지션을 흔들지 않게, 각도를 저역통과(smoothing)로 다듬고
///   경계에 **히스테리시스**를 둬 칸이 딸깍딸깍 튀지 않게 한다.
/// - **중립 기준:** `start()` 시점의 기울기를 0점으로 잡아, 어떤 자세로 들든 그 자리가 1프렛이 되게.
///
/// - Note: iPhone은 세로 고정 + 콘텐츠 -90° 회전이라, "넥 방향으로 기울임"에 해당하는 축·부호는
///   **실기기에서 최종 조정**이 필요하다. 지금은 roll을 쓰고 위 보정만 걸어둔다.
@MainActor
final class MotionNeckPositionProvider: NeckPositionProviding, ObservableObject {
    @Published private(set) var position: Int = 0
    let maxPosition: Int

    var positionChanged: AnyPublisher<Int, Never> { $position.eraseToAnyPublisher() }

    private let motion = CMMotionManager()
    /// 최대 오프셋에 도달하는 데 필요한 기울기(라디안). 이 각도만큼 기울이면 끝까지 간다.
    private let travelAngle: Double
    /// 각도 저역통과 계수 (작을수록 부드럽지만 느리다).
    private let smoothing: Double = 0.18
    /// 칸 튐 방지용 히스테리시스(칸 폭 대비 여유).
    private let hysteresis: Double = 0.35

    private var neutralAngle: Double?
    private var smoothedAngle: Double = 0

    init(maxPosition: Int, travelAngle: Double = 0.7) {
        self.maxPosition = maxPosition
        self.travelAngle = max(travelAngle, 0.01)
    }

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        neutralAngle = nil
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.handle(rawAngle: data.attitude.roll)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    private func handle(rawAngle: Double) {
        // 처음 값을 중립(0프렛)으로 잡는다.
        if neutralAngle == nil {
            neutralAngle = rawAngle
            smoothedAngle = rawAngle
        }
        guard let neutral = neutralAngle else { return }

        // 저역통과로 손떨림을 다듬는다.
        smoothedAngle += (rawAngle - smoothedAngle) * smoothing

        // 중립 대비 이동 비율 0...1 → 오프셋. 사운드홀 쪽으로만 이동(음수는 0으로).
        let delta = smoothedAngle - neutral
        let ratio = min(max(delta / travelAngle, 0), 1)
        let target = ratio * Double(maxPosition)

        // 히스테리시스: 현재 칸에서 hysteresis 이상 벗어나야 다음 칸으로.
        if abs(target - Double(position)) >= (0.5 + hysteresis) {
            position = Int(target.rounded())
        }
    }
}
