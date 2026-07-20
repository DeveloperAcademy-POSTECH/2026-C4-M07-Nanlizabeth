import Foundation

/// 합주할 때 이 기기가 맡는 손. (ARCHITECTURE §3.8)
enum PeerHandRole: String, Equatable {
    /// 왼손 — 코드를 짚고 상대에게 보낸다. (iPhone)
    case fingering
    /// 오른손 — 긁고, **소리를 낸다.** (iPad)
    case strumming

    var displayName: String {
        switch self {
        case .fingering: return "코드 (왼손)"
        case .strumming: return "스트로크 (오른손)"
        }
    }

    /// 이 역할이 소리를 내는가.
    ///
    /// 소리는 **긁는 기기에서만** 난다 — 네트워크 지연이 스트럼 타이밍을 망치지 않게 하기 위한
    /// 결정 (`docs/adr/0001-multipeer-connectivity.md`).
    var producesSound: Bool { self == .strumming }

    /// 이 역할에 대응하는 연주 모드.
    ///
    /// **연결 여부에 따라 달라진다** — 이걸 구분하지 않으면 혼자 쓰는 사용자가
    /// 원격 소스를 기다리며 아무 소리도 못 내게 된다.
    ///
    /// | 역할 | 단독 | 연결됨 |
    /// |------|------|--------|
    /// | 왼손(iPhone) | 모드 A 코드 연습 | 모드 C 짚기 담당 (전송만) |
    /// | 오른손(iPad) | 모드 B 스트로크 연습 | 모드 C 긁기 담당 (소리 남) |
    ///
    /// iPad 단독이 모드 B가 되는 근거: 오른손은 직접 긁고, 왼손은 코드진행이 자동으로 짚어준다.
    /// 그래서 iPad에도 **코드진행 선택 화면이 필요**하다 (스트럼 화면의 ⓒ 버튼).
    func playMode(isConnected: Bool) -> PlayMode {
        switch (self, isConnected) {
        case (.fingering, false): return .chordPractice
        case (.fingering, true): return .ensembleFingerer
        case (.strumming, false): return .strumPractice
        case (.strumming, true): return .ensembleStrummer
        }
    }
}

/// **역할은 기기 종류로 고정된다 — 협상 없음.** (ARCHITECTURE §3.8, SPEC 플로우 3)
///
/// iPad가 오른손인 이유: 화면이 넓어 긁는 동작이 자연스럽고, 소리도 여기서 나야 하기 때문.
///
/// ```swift
/// let role = PeerRolePolicy.role(for: DeviceInfoProvider.currentDeviceType)
/// ```
enum PeerRolePolicy {
    static func role(for deviceType: DeviceType) -> PeerHandRole {
        switch deviceType {
        case .iPad:
            return .strumming
        case .iPhone, .unknown:
            // 알 수 없는 기기는 iPhone으로 취급한다 — 짚기는 어느 화면 크기에서나 가능하다.
            return .fingering
        }
    }

    /// 두 기기가 서로 다른 역할인가 (합주가 성립하는가).
    static func canPair(_ a: DeviceType, _ b: DeviceType) -> Bool {
        role(for: a) != role(for: b)
    }
}

/// 연결 화면(화면 8·9)이 **이 상태만 보고 그린다.** (ARCHITECTURE §3.8)
///
/// ```
/// idle → guide(첫 회만) → browsing → inviting → connected
///                                                    ↓
///                                              disconnected
/// ```
enum ConnectionFlowState: Equatable {
    /// 아직 아무것도 안 함.
    case idle
    /// 처음 연결하는 사용자에게 보여주는 안내. **스킵 가능.**
    case guide
    /// 근처 기기 찾는 중.
    case browsing
    /// 초대를 보내고 응답 기다리는 중.
    case inviting(peerName: String)
    case connected(peerName: String)
    /// 연결이 끊김.
    ///
    /// - Note: ⚠️ 끊겼을 때 연주를 멈출지·단독 모드로 갈지는 **SPEC §8 열린 결정**.
    case disconnected(reason: String?)
    case failed(message: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    /// 지금 기기를 찾는 중인가 (스피너 표시용).
    var isSearching: Bool {
        switch self {
        case .browsing, .inviting: return true
        default: return false
        }
    }

    var displayName: String {
        switch self {
        case .idle: return "대기"
        case .guide: return "안내"
        case .browsing: return "기기 찾는 중"
        case .inviting(let name): return "\(name)에 연결 요청 중"
        case .connected(let name): return "\(name)와 연결됨"
        case .disconnected(let reason): return reason.map { "연결 끊김: \($0)" } ?? "연결 끊김"
        case .failed(let message): return "실패: \(message)"
        }
    }
}

/// "연결 가이드를 봤는가"를 기억한다. (SPEC §7 저장 항목)
///
/// **스킵도 "봤음"으로 친다** — 한 번 건너뛴 사람에게 매번 다시 보여주지 않는다.
@MainActor
protocol PeerGuideStoreProtocol: AnyObject {
    var hasSeenGuide: Bool { get }
    func markGuideSeen()
    /// 연결 버튼을 눌렀을 때 가야 할 첫 단계.
    func initialFlowState() -> ConnectionFlowState
}

extension PeerGuideStoreProtocol {
    func initialFlowState() -> ConnectionFlowState {
        hasSeenGuide ? .browsing : .guide
    }
}

/// `UserDefaults`에 저장하는 기본 구현.
@MainActor
final class PeerGuideStore: PeerGuideStoreProtocol {
    private enum Key {
        static let hasSeenGuide = "peer.hasSeenGuide"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasSeenGuide: Bool {
        defaults.bool(forKey: Key.hasSeenGuide)
    }

    func markGuideSeen() {
        defaults.set(true, forKey: Key.hasSeenGuide)
    }
}

// MARK: - Mock

/// 저장하지 않는 가짜 가이드 저장소. (ARCHITECTURE §4.1)
///
/// 연결 화면(U7)에서 **가이드 화면을 매번 다시 보며** 개발할 때 쓴다.
@MainActor
final class MockPeerGuideStore: PeerGuideStoreProtocol {
    private(set) var hasSeenGuide: Bool

    init(hasSeenGuide: Bool = false) {
        self.hasSeenGuide = hasSeenGuide
    }

    func markGuideSeen() {
        hasSeenGuide = true
    }
}
