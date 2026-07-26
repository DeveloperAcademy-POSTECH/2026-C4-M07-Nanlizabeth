import SwiftUI

struct PeerButtonBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// 상단 컨트롤 바가 **실제로 차지하는 크기**. 버튼은 오른쪽 끝에 붙어 있고 펼침 여부에 따라
/// 폭이 크게 달라지는데, 이걸 재야 나머지 넓은 빈 자리를 악기 터치에 돌려줄 수 있다.
struct TopControlBarContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize?

    static func reduce(value: inout CGSize?, nextValue: () -> CGSize?) {
        value = nextValue() ?? value
    }
}

struct BPMButtonBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// 연주 화면을 덮는 UIKit 멀티터치 레이어에서 제외할 실제 컨트롤 영역.
/// TopControlBar의 기존 위치·크기(상단 20, 우측 60, 최대 너비 690)를 그대로 반영한다.
enum InstrumentControlHitRegion {
    static let topBar = CGRect(x: 116, y: 12, width: 706, height: 62)
    static let peerPopover = CGRect(x: 60, y: 76, width: 360, height: 240)
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
    /// 멀티피어 연결 중에는 상대 기기와 역할이 나뉘므로 세그먼트 우측의 단독 연주 컨트롤을 감춘다.
    var hidesStandaloneControls: Bool = false
    /// 코드 드릴 진입 (코드 모드에서만 노출). `nil`이면 버튼을 감춘다.
    var onStartDrill: (() -> Void)? = nil
    /// 첫 실행 튜토리얼에서 지금 눌러야 할 상단 컨트롤.
    var tutorialHighlight: TutorialHighlightTarget? = nil
    let onModeChange: (PrototypeMode) -> Void
    let onPeer: () -> Void
    let onAction: () -> Void
    let onTogglePlayback: () -> Void
    let onToggleBPM: () -> Void
    let onToggleControls: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if isExpanded {
                HStack(spacing: 10) {
                    // 연결(멀티피어) 버튼 왼쪽 — 음악/드릴 진입 버튼.
                    if let onStartDrill {
                        LiquidGlassGlyphButton("♫", action: onStartDrill)
                            .tutorialPulseHighlight(
                                tutorialHighlight == .songSelectionButton,
                                cornerRadius: 23
                            )
                    }

                    PeerLiquidGlassButton(state: peerButtonState, action: onPeer)
                        .tutorialPulseHighlight(tutorialHighlight == .peerButton, cornerRadius: 23)
                        .anchorPreference(
                            key: PeerButtonBoundsPreferenceKey.self,
                            value: .bounds
                        ) { $0 }

                    if showsModeToggle {
                        SegmentedModeControl(
                            mode: mode,
                            highlightsStrumSegment: tutorialHighlight == .strumModeSegment,
                            onModeChange: onModeChange
                        )
                            .frame(width: 155, height: 46)
                    }

                    if !hidesStandaloneControls {
                        LiquidGlassAssetIconButton(
                            assetName: actionTitle == "C" ? "chordSelectIcon" : "strumSelectIcon",
                            action: onAction
                        )
                        .tutorialPulseHighlight(
                            tutorialHighlight == .strumSelectionButton,
                            cornerRadius: 23
                        )

                        LiquidGlassTextButton("BPM", action: onToggleBPM)
                            .disabled(!bpmEnabled)
                            .opacity(bpmEnabled ? 1 : 0.4)
                            .tutorialPulseHighlight(
                                tutorialHighlight == .bpmButton,
                                cornerRadius: 23
                            )
                            .anchorPreference(
                                key: BPMButtonBoundsPreferenceKey.self,
                                value: .bounds
                            ) { $0 }

                        LiquidGlassIconButton(
                            systemName: isPlaying ? "pause.fill" : "play.fill",
                            action: onTogglePlayback
                        )
                        .tutorialPulseHighlight(
                            tutorialHighlight == .playButton,
                            cornerRadius: 23
                        )
                    }
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
        // 버튼 줄의 실제 크기를 재서 알린다. 바깥 `.frame(maxWidth:)`보다 **먼저** 재야
        // 화면 전체 폭이 아니라 버튼이 실제로 덮는 만큼만 잡힌다.
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TopControlBarContentSizePreferenceKey.self,
                    value: proxy.size
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
    }
}

private struct SegmentedModeControl: View {
    let mode: PrototypeMode
    var highlightsStrumSegment = false
    let onModeChange: (PrototypeMode) -> Void

    var body: some View {
        Picker(
            "연주 모드",
            selection: Binding(
                get: { mode },
                set: { nextMode in
                    guard nextMode != mode else { return }
                    onModeChange(nextMode)
                }
            )
        ) {
            Text("코드")
                .tag(PrototypeMode.chord)
            Text("스트로크")
                .tag(PrototypeMode.strum)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.large)
        .font(.system(size: 15, weight: .semibold))
        .overlay(alignment: .trailing) {
            if highlightsStrumSegment {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(width: 77.5)
                    .tutorialPulseHighlight(true, cornerRadius: 23)
                    .allowsHitTesting(false)
            }
        }
    }
}
