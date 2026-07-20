import SwiftUI

struct TopControlBar: View {
    let mode: PrototypeMode
    let isPlaying: Bool
    let isExpanded: Bool
    let peerButtonState: PrototypePeerButtonState
    let actionTitle: String
    let onModeChange: (PrototypeMode) -> Void
    let onPeer: () -> Void
    let onAction: () -> Void
    let onTogglePlayback: () -> Void
    let onToggleBPM: () -> Void
    let onToggleControls: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if isExpanded {
                HStack(spacing: 12) {
                    PeerLiquidGlassButton(state: peerButtonState, action: onPeer)

                    SegmentedModeControl(mode: mode, onModeChange: onModeChange)
                        .frame(width: 310, height: 46)

                    LiquidGlassTextButton("BPM", action: onToggleBPM)

                    LiquidGlassIconButton(
                        systemName: isPlaying ? "pause.fill" : "play.fill",
                        action: onTogglePlayback
                    )

                    LiquidGlassTextButton(actionTitle, action: onAction)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            LiquidGlassIconButton(systemName: isExpanded ? "chevron.right" : "chevron.left") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    onToggleControls()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
    }
}

private struct SegmentedModeControl: View {
    let mode: PrototypeMode
    let onModeChange: (PrototypeMode) -> Void

    var body: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.black.opacity(0.38)))
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))

            HStack(spacing: 0) {
                segment("코드", isSelected: mode == .chord) {
                    onModeChange(.chord)
                }
                segment("스트로크", isSelected: mode == .strum) {
                    onModeChange(.strum)
                }
            }
        }
    }

    private func segment(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
                        .background(
                            Capsule()
                                .fill(isSelected ? .ultraThinMaterial : .regularMaterial)
                                .opacity(isSelected ? 1 : 0)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
