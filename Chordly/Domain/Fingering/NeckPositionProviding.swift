import Combine
import Foundation

/// 넥 **입력 방식** — 슬라이더냐 코어모션이냐. A/B 테스트로 무엇이 더 좋은 경험인지 비교한다.
enum NeckPositionMode: String, CaseIterable, Identifiable {
    case slider
    case motion
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .slider: return "슬라이더"
        case .motion: return "모션"
        }
    }
}

/// 넥 **포지션** 공급자 — 화면 첫 프렛 칸이 **실제 몇 프렛인지의 오프셋**(0부터)을 준다.
/// (docs/PLAN-neck-position)
///
/// - `0`이면 1프렛부터(너트·튜닝손잡이 근처, 기존 동작)
/// - 커질수록 **사운드홀 쪽 높은 프렛**으로 옮겨가며 짚을 수 있다.
///
/// 입력 방식(슬라이더·코어모션)을 **갈아끼우려고 인터페이스로 뺐다** — 같은 넥에 꽂아 A/B 비교.
@MainActor
protocol NeckPositionProviding: AnyObject {
    /// 현재 오프셋 (0...maxPosition).
    var position: Int { get }
    /// 오프셋 변화 스트림.
    var positionChanged: AnyPublisher<Int, Never> { get }
    /// 갈 수 있는 최대 오프셋 (넥이 몸통과 만나는 곳까지).
    var maxPosition: Int { get }
    /// 입력 시작/정지 (모션 센서 등 리소스 관리). 슬라이더는 할 일이 없다.
    func start()
    func stop()
}

extension NeckPositionProviding {
    func start() {}
    func stop() {}
}

/// 🎚️ **슬라이더 버전** — 화면의 슬라이드바가 포지션을 정한다.
@MainActor
final class SliderNeckPositionProvider: NeckPositionProviding, ObservableObject {
    @Published var position: Int = 0
    let maxPosition: Int

    var positionChanged: AnyPublisher<Int, Never> { $position.eraseToAnyPublisher() }

    init(maxPosition: Int) {
        self.maxPosition = maxPosition
    }

    /// SwiftUI `Slider`(Double)와 잇는 편의 값. 정수 오프셋으로 반올림·클램프한다.
    var sliderValue: Double {
        get { Double(position) }
        set { position = min(max(Int(newValue.rounded()), 0), maxPosition) }
    }
}
