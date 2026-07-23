import SwiftUI

/// 연주 화면을 덮는 UIKit 멀티터치 레이어에서 제외할 실제 컨트롤 영역.
/// TopControlBar의 기존 위치·크기(상단 20, 우측 60, 최대 너비 690)를 그대로 반영한다.
enum InstrumentControlHitRegion {
    static let topBar = CGRect(x: 116, y: 12, width: 706, height: 62)
    static let peerPopover = CGRect(x: 60, y: 76, width: 276, height: 240)
}

struct TopControlBar: View {
    let mode: PrototypeMode
    let isPlaying: Bool
    let isExpanded: Bool
    let peerButtonState: PrototypePeerButtonState
    let actionTitle: String
    /// iPad는 항상 스트로크만 하므로 모드 토글을 숨긴다.
    var showsModeToggle: Bool = true
    /// BPM은 일시정지 중에만 바꿀 수 있다 — 재생 중이면 버튼을 흐리게·비활성화한다.
    var bpmEnabled: Bool = true
    /// 코드 드릴 진입 (코드 모드에서만 노출). `nil`이면 버튼을 감춘다.
    var onStartDrill: (() -> Void)? = nil
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
                    // 연결(멀티피어) 버튼 왼쪽 — 코드 모드에서만 코드 드릴 진입 버튼.
                    if mode == .chord, let onStartDrill {
                        LiquidGlassIconButton(systemName: "target", action: onStartDrill)
                    }

                    PeerLiquidGlassButton(state: peerButtonState, action: onPeer)

                    if showsModeToggle {
                        SegmentedModeControl(mode: mode, onModeChange: onModeChange)
                            .frame(width: 310, height: 46)
                    }

                    LiquidGlassTextButton("BPM", action: onToggleBPM)
                        .disabled(!bpmEnabled)
                        .opacity(bpmEnabled ? 1 : 0.4)

                    LiquidGlassIconButton(
                        systemName: isPlaying ? "pause.fill" : "play.fill",
                        action: onTogglePlayback
                    )

                    LiquidGlassAssetIconButton(
                        assetName: actionTitle == "C" ? "chordSelectIcon" : "strumSelectIcon",
                        action: onAction
                    )
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            LiquidGlassCompactToggleButton(
                systemName: isExpanded ? "chevron.compact.right" : "chevron.compact.left"
            ) {
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
            Color.clear
                .glassEffect(.regular, in: .capsule)
                .allowsHitTesting(false)

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
                .background {
                    if isSelected {
                        Color.clear
                            .glassEffect(
                                .regular.tint(Color.white.opacity(0.12)),
                                in: .capsule
                            )
                            .allowsHitTesting(false)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
