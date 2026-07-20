import SwiftUI
import UIKit

/// 손가락 하나를 가리키는 식별자.
///
/// `UITouch` 객체를 그대로 들고 있지 않는다 — Apple이 이벤트 처리 밖에서 붙잡지 말라고 명시한
/// 객체라, 신원만 복사해 남긴다.
struct TouchID: Hashable {
    private let value: ObjectIdentifier

    init(_ touch: UITouch) {
        value = ObjectIdentifier(touch)
    }
}

/// 멀티터치를 그대로 넘겨주는 투명 레이어.
///
/// ## 왜 필요한가
///
/// **SwiftUI 제스처로는 기타를 칠 수 없다.** `DragGesture`는 손가락을 **하나만** 알려줘서,
/// 세 손가락으로 화음을 짚어도 하나만 들어오고, 아르페지오처럼 여러 줄을 동시에 튕기면
/// 한 줄만 울린다. 손가락을 전부 받으려면 `isMultipleTouchEnabled`가 켜진 `UIView`가 필요하다.
///
/// ## 어떻게 넘겨주나
///
/// 매 이벤트마다 **"지금 닿아 있는 손가락 전부"** 를 통째로 준다. began/ended를 낱개로 주면
/// 손가락이 빠르게 엇갈릴 때 상태가 어긋나는데, 스냅샷으로 주면 순서가 꼬여도 어긋날 수 없다.
///
/// ```swift
/// MultiTouchLayer { touches in
///     // touches: [TouchID: CGPoint] — 이 뷰의 좌표계 기준
///     viewModel.handleTouches(touches)
/// }
/// ```
struct MultiTouchLayer: UIViewRepresentable {
    /// 지금 닿아 있는 손가락 전부. 손을 다 떼면 빈 사전이 온다.
    let onTouchesChanged: ([TouchID: CGPoint]) -> Void

    func makeUIView(context: Context) -> MultiTouchView {
        let view = MultiTouchView()
        view.onTouchesChanged = onTouchesChanged
        return view
    }

    func updateUIView(_ uiView: MultiTouchView, context: Context) {
        uiView.onTouchesChanged = onTouchesChanged
    }
}

/// 실제 터치를 받는 UIKit 뷰. 좌표의 **의미 해석은 하지 않는다** — 그건 쓰는 쪽 몫이다.
final class MultiTouchView: UIView {
    var onTouchesChanged: (([TouchID: CGPoint]) -> Void)?

    private var touchPoints: [TouchID: CGPoint] = [:]

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
    /// 계속 닿아 있는 것으로 남는다.**
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        forget(touches)
    }

    private func updatePositions(of touches: Set<UITouch>) {
        for touch in touches {
            touchPoints[TouchID(touch)] = touch.location(in: self)
        }
        onTouchesChanged?(touchPoints)
    }

    private func forget(_ touches: Set<UITouch>) {
        for touch in touches {
            touchPoints.removeValue(forKey: TouchID(touch))
        }
        onTouchesChanged?(touchPoints)
    }
}
