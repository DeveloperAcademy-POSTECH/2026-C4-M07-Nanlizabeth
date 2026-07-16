import SwiftUI

struct StringInputLayerView: View {
    let onChanged: (CGPoint, CGSize) -> Void
    let onEnded: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            onChanged(value.location, proxy.size)
                        }
                        .onEnded { _ in
                            onEnded()
                        }
                )
        }
    }
}
