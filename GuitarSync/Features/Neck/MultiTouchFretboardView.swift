import SwiftUI
import UIKit

/// 멀티터치를 받아 **"지금 눌린 칸 전부"** 를 스냅샷으로 올려보낸다. (ARCHITECTURE §3.4 · 태스크 U2)
///
/// ## 왜 UIKit으로 내려가나
///
/// **SwiftUI 제스처로는 화음을 못 짚는다.** `DragGesture`는 손가락을 하나만 알려줘서,
/// 세 손가락으로 C코드를 짚어도 하나만 들어온다. SPEC §4가 요구하는 "여러 칸을 여러 손가락으로
/// 동시에"를 만족하려면 `isMultipleTouchEnabled`가 켜진 `UIView`가 필요하다.
///
/// (스트럼 화면의 `StringInputLayerView`는 손가락 하나로 긁는 동작이라 `DragGesture`로 충분하다.
/// 넥과 스트럼의 입력 방식이 다른 이유다.)
///
/// ## 왜 낱개가 아니라 스냅샷으로 올리나
///
/// began/ended를 하나씩 올리면 손가락이 빠르게 엇갈릴 때 상태가 어긋난다. 매 이벤트마다
/// **"지금은 이게 전부다"** 를 통째로 넘기면 순서가 꼬여도 어긋날 수 없다. (§3.4의 설계 의도)
struct MultiTouchFretboardView: UIViewRepresentable {
    /// 눌린 칸이 바뀔 때마다 호출된다. 손을 다 떼면 빈 집합이 온다.
    let onPressesChanged: (Set<FretPress>) -> Void

    func makeUIView(context: Context) -> FretboardTouchView {
        let view = FretboardTouchView()
        view.onPressesChanged = onPressesChanged
        return view
    }

    func updateUIView(_ uiView: FretboardTouchView, context: Context) {
        uiView.onPressesChanged = onPressesChanged
    }
}

/// 실제 터치를 받는 UIKit 뷰. 좌표 해석은 `NeckGeometry`에 맡기고 여기서는 손가락만 센다.
final class FretboardTouchView: UIView {
    var onPressesChanged: ((Set<FretPress>) -> Void)?

    /// 손가락별 현재 위치.
    ///
    /// **`UITouch` 객체를 그대로 들고 있지 않는다** — Apple이 이벤트 처리 밖에서 붙잡지 말라고
    /// 명시한 객체라, 식별자와 좌표만 복사해 남긴다.
    private var touchPoints: [ObjectIdentifier: CGPoint] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("코드로만 만든다 — 스토리보드를 쓰지 않는 프로젝트다.")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        updatePositions(of: touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updatePositions(of: touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        forget(touches)
    }

    /// 전화가 오거나 시스템이 터치를 회수한 경우. **여기서 안 지우면 손을 뗐는데도
    /// 계속 짚고 있는 것으로 남는다.**
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        forget(touches)
    }

    private func updatePositions(of touches: Set<UITouch>) {
        for touch in touches {
            touchPoints[ObjectIdentifier(touch)] = touch.location(in: self)
        }
        publish()
    }

    private func forget(_ touches: Set<UITouch>) {
        for touch in touches {
            touchPoints.removeValue(forKey: ObjectIdentifier(touch))
        }
        publish()
    }

    private func publish() {
        // 지판 밖(컨트롤 바 위 등)에 있는 손가락은 `press(at:)`가 걸러낸다.
        let presses = Set(touchPoints.values.compactMap(NeckGeometry.press(at:)))
        onPressesChanged?(presses)
    }
}
