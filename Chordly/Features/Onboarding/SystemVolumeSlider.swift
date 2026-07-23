import SwiftUI
import MediaPlayer

/// 시스템 볼륨을 직접 조절하는 슬라이더. (`MPVolumeView` 래핑 · SPEC 플로우4)
///
/// 앱이 볼륨을 **강제로 못 바꾸는** 대신, 사용자가 화면에서 직접 올릴 수 있게 시스템 슬라이더를
/// 그대로 얹는다.
///
/// - Important: ⚠️ **`MPVolumeView`는 UIKit 뷰라 스테이지 회전을 따라오지 않는다** (ARCHITECTURE §2.5).
///   그래서 온보딩에서만 쓰고, 회전이 어색하면 "설정에서 올려주세요" 안내로 대체할 수 있게 분리해 뒀다.
/// - Note: **시뮬레이터에는 볼륨 하드웨어가 없어 아무것도 안 보인다.** 실기기에서만 슬라이더가 뜬다.
struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.showsRouteButton = false
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
