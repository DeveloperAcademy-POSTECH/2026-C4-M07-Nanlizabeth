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
                .background {
                    Color.clear
                        .glassEffect(.regular, in: .circle)
                        .allowsHitTesting(false)
                }
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
                .foregroundStyle(isActive ? Color.gsAccent : .white)
                .frame(width: 46, height: 46)
                .background {
                    Color.clear
                        .glassEffect(.regular, in: .circle)
                        .allowsHitTesting(false)
                }
                .opacity(opacity)
        }
        .buttonStyle(.plain)
    }
}

/// 컨트롤 바의 펼치기·숨기기 전용 버튼.
/// 일반 원형 버튼보다 가로폭이 좁아 다른 액션 버튼과 성격을 구분한다.
struct LiquidGlassCompactToggleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 46)
                .background {
                    Color.clear
                        .glassEffect(.regular, in: .capsule)
                        .allowsHitTesting(false)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "chevron.compact.right" ? "컨트롤 숨기기" : "컨트롤 펼치기")
    }
}

/// 커스텀 SVG 에셋을 표시하는 Liquid Glass 버튼.
/// 기존 C/S 텍스트 버튼과 같은 62×46 프레임을 유지한다.
struct LiquidGlassAssetIconButton: View {
    let assetName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 26, height: 28)
                .frame(width: 62, height: 46)
                .background {
                    Color.clear
                        .glassEffect(.regular, in: .circle)
                        .allowsHitTesting(false)
                }
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
            return "rectangle.badge.plus"
        case .connecting:
            return "link"
        case .connected:
            return "ipad.landscape.and.iphone"
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
