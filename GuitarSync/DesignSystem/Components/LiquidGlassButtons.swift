import SwiftUI

struct LiquidGlassTextButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 46)
                .liquidGlassCircle(isActive: false)
        }
        .buttonStyle(.plain)
    }
}

struct LiquidGlassIconButton: View {
    let systemName: String
    var isActive = false
    var opacity: Double = 1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .liquidGlassCircle(isActive: isActive)
                .opacity(opacity)
        }
        .buttonStyle(.plain)
    }
}

struct PeerLiquidGlassButton: View {
    let state: PrototypePeerButtonState
    let action: () -> Void
    @State private var isBlinking = false

    var body: some View {
        LiquidGlassIconButton(
            systemName: systemName,
            isActive: state == .connected,
            opacity: state == .connecting && isBlinking ? 0.38 : 1,
            action: action
        )
        .onAppear(perform: updateBlinking)
        .onChange(of: state) { _, _ in
            updateBlinking()
        }
    }

    private var systemName: String {
        switch state {
        case .disconnected:
            return "link.badge.plus"
        case .connecting:
            return "link"
        case .connected:
            return "link.circle.fill"
        }
    }

    private func updateBlinking() {
        guard state == .connecting else {
            isBlinking = false
            return
        }

        withAnimation(.easeInOut(duration: 0.58).repeatForever(autoreverses: true)) {
            isBlinking = true
        }
    }
}

private extension View {
    func liquidGlassCircle(isActive: Bool) -> some View {
        background(
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().fill(Color.black.opacity(isActive ? 0.18 : 0.42)))
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.30), Color.white.opacity(0.05), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 8)
        )
        .overlay(Circle().stroke(Color.white.opacity(isActive ? 0.42 : 0.22), lineWidth: 1))
    }
}
