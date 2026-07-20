import Combine
import Foundation

/// 앱의 화면 목록. **SPEC §6 화면표와 1:1.** (ARCHITECTURE §3.9)
enum AppRoute: Hashable, Identifiable, CaseIterable {
    /// 1. 첫 실행 안내 + 볼륨/방해금지 세팅 유도
    case onboarding
    /// 2. 기타넥 — 코드 짚기 (iPhone 메인)
    case neck
    /// 3. 스트럼 — 줄 긁기 (iPad 메인 / iPhone 모드 B)
    case strum
    /// 4. 스트로크 선택 — 프리셋 주법 목록
    case strokeSelect
    /// 6. 코드진행 선택 — 프리셋 진행 목록
    case progressionSelect
    /// 7. 코드진행 커스텀 — 카탈로그에서 코드 골라 배치 + 미리듣기
    case progressionCustom
    /// 8. 연결 가이드 — 첫 연결 안내 (스킵 가능)
    case peerGuide
    /// 9. 근처 기기 찾기 — 탐색·초대·연결 상태
    case peerBrowse

    var id: Self { self }

    /// 화면 상단 등에 쓰는 이름.
    ///
    /// - Note: Figma HI-FI 페이지명이 확정되면 여기에 맞춘다 (태스크 F2).
    var title: String {
        switch self {
        case .onboarding: return "시작하기"
        case .neck: return "기타넥"
        case .strum: return "스트럼"
        case .strokeSelect: return "스트로크 선택"
        case .progressionSelect: return "코드진행 선택"
        case .progressionCustom: return "코드진행 만들기"
        case .peerGuide: return "연결 안내"
        case .peerBrowse: return "기기 찾기"
        }
    }

    /// 연주 화면인가 — 진입 시 **화면 꺼짐 방지**를 켜야 하는 화면 (ARCHITECTURE §3.10).
    var isPerformanceScreen: Bool {
        self == .neck || self == .strum
    }
}

/// **모든 화면 전환은 이 안내데스크를 거친다.** (ARCHITECTURE §3.9)
///
/// 뷰 안에서 직접 다른 화면을 띄우지 않는다. 그래야 "그 화면 어떻게 여는 거예요?"라는
/// 질문이 사라지고, 전환 방식이 사람마다 달라지지 않는다.
///
/// ```swift
/// @EnvironmentObject private var router: AppRouter
/// Button("주법 고르기") { router.navigate(to: .strokeSelect) }
/// Button("뒤로")       { router.back() }
/// ```
@MainActor
final class AppRouter: ObservableObject {
    /// 지금 보이는 화면.
    @Published private(set) var currentRoute: AppRoute
    /// 뒤로 가기용 방문 기록 (현재 화면은 포함하지 않는다).
    @Published private(set) var history: [AppRoute] = []

    private let onboardingStore: OnboardingStoreProtocol

    /// - Parameter onboardingStore: 생략하면 `UserDefaults` 기반 실제 저장소.
    ///   온보딩 화면을 반복해서 보며 개발하려면 `MockOnboardingStore()`를 넘긴다.
    init(
        deviceType: DeviceType = DeviceInfoProvider.currentDeviceType,
        onboardingStore: OnboardingStoreProtocol? = nil
    ) {
        // 기본값을 인자 자리에 두면 nonisolated 컨텍스트에서 평가돼 @MainActor와 충돌한다.
        let store = onboardingStore ?? OnboardingStore()
        self.onboardingStore = store
        self.currentRoute = Self.startRoute(deviceType: deviceType, onboardingStore: store)
    }

    /// 앱을 켰을 때 어느 화면으로 갈 것인가. (ARCHITECTURE §3.9 시작 규칙)
    ///
    /// 1. 온보딩을 아직 안 봤으면 → 온보딩
    /// 2. iPad → 스트럼 (항상 오른손이므로)
    /// 3. 그 외 → 기타넥
    static func startRoute(
        deviceType: DeviceType,
        onboardingStore: OnboardingStoreProtocol
    ) -> AppRoute {
        #if DEBUG
        if let forced = debugForcedRoute { return forced }
        #endif
        guard onboardingStore.hasCompletedOnboarding else { return .onboarding }
        return PeerRolePolicy.role(for: deviceType) == .strumming ? .strum : .neck
    }

    #if DEBUG
    /// 실행 인자로 시작 화면을 강제한다 — **자기 화면만 반복해서 보며 개발할 때** 쓴다.
    ///
    /// Xcode의 Scheme → Run → Arguments에 아래를 추가하면 그 화면으로 바로 뜬다.
    /// ```
    /// -startRoute progressionCustom
    /// ```
    /// 명령줄에서도 된다:
    /// ```sh
    /// xcrun simctl launch <device> <bundle-id> -startRoute peerGuide
    /// ```
    static var debugForcedRoute: AppRoute? {
        guard let name = UserDefaults.standard.string(forKey: "startRoute") else { return nil }
        return AppRoute.allCases.first { "\($0)" == name }
    }
    #endif

    // MARK: - 이동

    func navigate(to route: AppRoute) {
        guard route != currentRoute else { return }
        history.append(currentRoute)
        currentRoute = route
    }

    /// 한 화면 뒤로. 기록이 없으면 아무 일도 하지 않는다.
    func back() {
        guard let previous = history.popLast() else { return }
        currentRoute = previous
    }

    var canGoBack: Bool { !history.isEmpty }

    /// 기록을 지우고 해당 화면으로 (온보딩 완료 후처럼 "돌아갈 곳이 없는" 이동).
    func replaceRoot(with route: AppRoute) {
        history.removeAll()
        currentRoute = route
    }

    /// 온보딩을 끝내고 기기에 맞는 메인 화면으로 보낸다.
    func completeOnboarding(deviceType: DeviceType = DeviceInfoProvider.currentDeviceType) {
        onboardingStore.markOnboardingCompleted()
        replaceRoot(with: PeerRolePolicy.role(for: deviceType) == .strumming ? .strum : .neck)
    }
}

// MARK: - 온보딩 저장소 (ARCHITECTURE §3.10)

/// "온보딩을 끝냈는가"를 기억한다. 완료하면 이후 자동 스킵 (SPEC §7).
@MainActor
protocol OnboardingStoreProtocol: AnyObject {
    var hasCompletedOnboarding: Bool { get }
    func markOnboardingCompleted()
}

/// `UserDefaults`에 저장하는 기본 구현.
@MainActor
final class OnboardingStore: OnboardingStoreProtocol {
    private enum Key {
        static let hasCompletedOnboarding = "onboarding.hasCompleted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Key.hasCompletedOnboarding)
    }

    func markOnboardingCompleted() {
        defaults.set(true, forKey: Key.hasCompletedOnboarding)
    }
}

/// 저장하지 않는 가짜 저장소. **온보딩 화면을 매번 다시 보며 개발**할 때 쓴다.
@MainActor
final class MockOnboardingStore: OnboardingStoreProtocol {
    private(set) var hasCompletedOnboarding: Bool

    init(hasCompletedOnboarding: Bool = false) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    func markOnboardingCompleted() {
        hasCompletedOnboarding = true
    }
}
