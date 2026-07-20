import AVFoundation
import Combine
import Foundation

/// 온보딩이 안내에 쓰는 시스템 상태. (ARCHITECTURE §3.10 · SPEC 플로우4)
///
/// **앱이 바꿀 수 있는 건 없다 — 읽기만 한다.** 볼륨을 강제로 올리는 건 비공개 API라 심사에서
/// 걸리고, 방해금지는 켜줄 수도 없다. 그래서 "지금 볼륨이 낮다"를 판정해 **안내**만 한다.
@MainActor
final class SystemSetupHelper: ObservableObject {
    /// 현재 출력 볼륨 (0~1).
    @Published private(set) var outputVolume: Float = 0.5

    /// 볼륨이 낮아 안내가 필요한가.
    var isVolumeLow: Bool { outputVolume < lowVolumeThreshold }

    private let lowVolumeThreshold: Float = 0.3
    private var observation: NSKeyValueObservation?

    init() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(true)
        outputVolume = session.outputVolume

        // outputVolume은 KVO로 볼 수 있다 — 사용자가 버튼으로 올리면 카드가 즉시 반응한다.
        observation = session.observe(\.outputVolume, options: [.initial, .new]) { [weak self] session, _ in
            let volume = session.outputVolume
            Task { @MainActor in self?.outputVolume = volume }
        }
        #endif
    }
}
