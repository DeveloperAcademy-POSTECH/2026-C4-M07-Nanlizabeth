import Combine
import CoreMotion
import Foundation

/// 📱 **코어모션 버전** — 기기를 **좌우로 기울여** 넥 포지션을 옮긴다. 기타를 쥐듯 랜드스케이프로 들고,
/// 넥 끝을 시소처럼 좌우로 기울이는 동작. (docs/PLAN-neck-position · A/B 상대편)
///
/// ## 왜 `gravity.y`인가 (축 분석)
///
/// 앱은 세로 고정 + 콘텐츠 -90° 회전이라, 유저는 폰을 90° 돌려 랜드스케이프로 쥔다. 이때:
/// - `attitude.roll`(기기 세로축=랜드스케이프에선 **넥의 긴 축** 회전)은 넥을 긴 축으로 굴리는
///   "로티세리"(화면이 위/아래로 눕는) 동작 → 유저가 **"위아래"로 느낀** 잘못된 축이었다.
/// - 유저가 원하는 **"좌우"**(넥 끝을 시소처럼 좌우로 기울임)는 **화면 밖 축(Z) 회전**이고,
///   이건 **중력의 기기 Y성분(`gravity.y`)에만** 나타난다.
///   - 중립(수직): `gravity ≈ (±1, 0, 0)` → `gravity.y ≈ 0`
///   - 좌우 시소 → `gravity.y`가 변함 ✓ · 로티세리(위아래) → `gravity.y`는 그대로(대신 `gravity.z`)
///
/// 그래서 `gravity.y`를 쓰면 **좌우 기울임만 골라내고 위아래와 분리**된다. 폰을 어느 방향
/// 랜드스케이프로 들든 성분은 같고 **부호만** 달라지므로, 부호는 `direction`으로 뒤집을 수 있다.
///
/// ## 좋은 기타 경험을 위해
/// - **중립 기준:** `start()` 시점 기울기를 0점으로 잡아, 어떤 자세로 들든 그 자리가 1프렛.
/// - **떨림 억제:** 저역통과(smoothing) + 칸 경계 **히스테리시스**로 딸깍 튐 방지.
///
/// - Note: 기울이는 **방향(부호)**·**감도(`travelTilt`)**는 실기기에서 손맛에 맞춰 미세조정한다.
@MainActor
final class MotionNeckPositionProvider: NeckPositionProviding, ObservableObject {
    @Published private(set) var position: Int = 0
    let maxPosition: Int

    var positionChanged: AnyPublisher<Int, Never> { $position.eraseToAnyPublisher() }

    private let motion = CMMotionManager()
    /// 끝(최고 프렛)까지 가는 데 필요한 좌우 기울기 — `gravity.y`(무차원 ±1) 기준. 0.55 ≈ 33° 기울임.
    private let travelTilt: Double
    /// 기울이는 방향 부호(+1/−1). 폰을 반대 랜드스케이프로 들면 뒤집는다.
    private let direction: Double
    /// 저역통과 계수 (작을수록 부드럽지만 느리다).
    private let smoothing: Double = 0.18
    /// 칸 튐 방지용 히스테리시스(칸 폭 대비 여유).
    private let hysteresis: Double = 0.35

    private var neutral: Double?
    private var smoothed: Double = 0

    init(maxPosition: Int, travelTilt: Double = 0.55, direction: Double = 1) {
        self.maxPosition = maxPosition
        self.travelTilt = max(travelTilt, 0.01)
        self.direction = direction >= 0 ? 1 : -1
    }

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        neutral = nil
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            // gravity.y = 좌우(시소) 기울기 성분. 위아래(로티세리)와 분리된다.
            self.handle(tilt: data.gravity.y)
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    private func handle(tilt: Double) {
        // 처음 값을 중립(0프렛)으로 잡는다.
        if neutral == nil {
            neutral = tilt
            smoothed = tilt
        }
        guard let neutral else { return }

        // 저역통과로 손떨림을 다듬는다.
        smoothed += (tilt - smoothed) * smoothing

        // 중립 대비 좌우 기울기 → 0...1. 한 방향으로 기울일수록 사운드홀 쪽으로.
        let delta = (smoothed - neutral) * direction
        let ratio = min(max(delta / travelTilt, 0), 1)
        let target = ratio * Double(maxPosition)

        // 히스테리시스: 현재 칸에서 일정 이상 벗어나야 다음 칸으로.
        if abs(target - Double(position)) >= (0.5 + hysteresis) {
            position = Int(target.rounded())
        }
    }
}
