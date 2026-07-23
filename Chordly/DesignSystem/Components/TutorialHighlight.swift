import SwiftUI

private struct TutorialPulseHighlightModifier: ViewModifier {
    let isActive: Bool
    let cornerRadius: CGFloat
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.gsAccent, lineWidth: 2.5)
                        .padding(-4)
                        .scaleEffect(isPulsing ? 1.08 : 1)
                        .opacity(isPulsing ? 0.35 : 1)
                        .shadow(color: Color.gsAccent.opacity(0.9), radius: isPulsing ? 12 : 5)
                        .allowsHitTesting(false)
                }
            }
            .onAppear { updatePulse() }
            .onChange(of: isActive) { _, _ in updatePulse() }
    }

    private func updatePulse() {
        guard isActive else {
            isPulsing = false
            return
        }

        isPulsing = false
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

extension View {
    /// 첫 실행 튜토리얼에서 지금 조작할 컨트롤을 라임색 펄스로 안내한다.
    func tutorialPulseHighlight(
        _ isActive: Bool,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(
            TutorialPulseHighlightModifier(
                isActive: isActive,
                cornerRadius: cornerRadius
            )
        )
    }
}
