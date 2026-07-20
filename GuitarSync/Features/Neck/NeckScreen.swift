import SwiftUI

/// 화면 2 — 기타넥 (iPhone 메인). (SPEC §6 화면2 · §4 개별 발음 / ROADMAP 태스크 U2)
///
/// Figma HI-FI `코드 모드 - 기본`을 옮긴 것이다. **좌표와 크기는 전부 `NeckGeometry`에서 읽는다** —
/// 이 파일에 숫자를 직접 쓰지 않는다 (ARCHITECTURE §5 규약).
///
/// ## 하는 일 세 가지
/// 1. 지판을 그린다 — 프렛 막대·줄·포지션 마크
/// 2. 멀티터치를 `FretPress`로 바꿔 뷰모델에 넘긴다. **소리 로직은 모른다** (ARCHITECTURE §3.4)
/// 3. 짚힌 자리에 점을 찍고, 울린 줄을 짧게 반짝인다
///
/// - Note: **iPhone 전용 화면**이다. 모드 C에서 iPad는 스트로크를 맡으므로 이 화면을 보지 않는다
///   (`PeerRolePolicy` · ARCHITECTURE §3.8).
struct NeckScreen: View {
    @ObservedObject var viewModel: NeckViewModel

    /// 운지가 바뀔 때 알려준다. 모드 C에서 iPad로 보내는 데 쓴다 (본격 연결은 N1).
    var onFingeringChanged: ((GuitarFingering) -> Void)?

    var body: some View {
        ZStack {
            board
            fretBars
            inlays
            strings
            pressMarkers

            // 맨 위에 깔아 손가락을 전부 받는다. 지판 밖 터치는 `NeckGeometry.press(at:)`가 걸러낸다.
            // 좌표를 "몇 번 줄 몇 프렛"으로 바꾸는 건 여기서 하고, 레이어는 손가락만 세어 준다.
            MultiTouchLayer { touches in
                viewModel.pressesChanged(Set(touches.values.compactMap(NeckGeometry.press(at:))))
            }
        }
        .frame(width: NeckGeometry.stage.width, height: NeckGeometry.stage.height)
        .onChange(of: viewModel.fingering) { _, fingering in
            onFingeringChanged?(fingering)
        }
        .onDisappear {
            // 화면을 벗어나면 짚고 있던 것으로 남지 않게 한다.
            viewModel.releaseAll()
        }
    }

    // MARK: - 자주 쓰는 치수

    private var boardHeight: CGFloat { NeckGeometry.boardBottom - NeckGeometry.boardTop }
    private var boardCenterY: CGFloat { (NeckGeometry.boardTop + NeckGeometry.boardBottom) / 2 }
    private var stageCenterX: CGFloat { NeckGeometry.stage.width / 2 }

    // MARK: - 레이어

    /// 지판. 위아래 가장자리를 어둡게 해 원통형 곡면을 흉내낸다.
    private var board: some View {
        LinearGradient(
            colors: [
                Color.gsSeparator,
                Color.gsNeckSurface,
                Color.gsNeckSurface,
                Color.gsSeparator,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: NeckGeometry.stage.width, height: boardHeight)
        .position(x: stageCenterX, y: boardCenterY)
    }

    /// 프렛 막대. **첫 번째가 너트**라 더 굵고 밝다.
    private var fretBars: some View {
        ForEach(Array(NeckGeometry.fretBoundaryXs.enumerated()), id: \.offset) { index, x in
            let isNut = index == 0

            Rectangle()
                .fill(metalFill(isNut: isNut))
                .frame(
                    width: isNut ? NeckGeometry.nutWidth : NeckGeometry.fretWidth,
                    height: boardHeight
                )
                .position(x: x, y: boardCenterY)
        }
    }

    /// 포지션 마크. 실제 기타처럼 3·5프렛 한가운데 높이에 찍힌다.
    private var inlays: some View {
        ForEach(NeckGeometry.inlayFrets, id: \.self) { fret in
            if let x = NeckGeometry.fretCenterX(fret) {
                Circle()
                    .fill(Color.gsTextPrimary)
                    .frame(width: NeckGeometry.inlayDiameter, height: NeckGeometry.inlayDiameter)
                    .overlay(Circle().stroke(Color.gsHardware, lineWidth: 2))
                    .position(x: x, y: NeckGeometry.boardCenterY)
            }
        }
    }

    /// 6줄. 위가 저음(굵음), 아래가 고음(얇음).
    private var strings: some View {
        ForEach(Array(NeckGeometry.stringYs.enumerated()), id: \.offset) { index, y in
            let thickness = NeckGeometry.stringThickness(index)
            let isFlashing = viewModel.flashingStrings.contains(index)

            GuitarStringLine(thickness: thickness)
                .frame(width: NeckGeometry.stage.width, height: thickness + 3)
                .position(x: stageCenterX, y: y)
                .shadow(color: .white.opacity(isFlashing ? 0.85 : 0), radius: 7)
        }
        .animation(.easeOut(duration: 0.18), value: viewModel.flashingStrings)
    }

    /// 지금 짚고 있는 자리. 손끝에 가리지 않도록 칸 한가운데에 크게 찍는다.
    private var pressMarkers: some View {
        ForEach(viewModel.activePresses.sorted(), id: \.self) { press in
            if let center = NeckGeometry.center(stringIndex: press.stringIndex, fret: press.fret) {
                Circle()
                    .fill(Color.gsAccent)
                    .frame(
                        width: NeckGeometry.pressMarkerDiameter,
                        height: NeckGeometry.pressMarkerDiameter
                    )
                    .overlay(Circle().stroke(Color.gsOnAccent.opacity(0.4), lineWidth: 2))
                    .position(center)
            }
        }
        .animation(.easeOut(duration: 0.12), value: viewModel.activePresses)
    }

    /// 금속 막대 느낌 — 가운데가 밝고 양옆이 어둡다.
    private func metalFill(isNut: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.gsHardware,
                Color.gsTextPrimary.opacity(isNut ? 1 : 0.82),
                Color.gsHardware,
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview("기타넥 — Mock (아무 데나 눌러도 Am)") {
    PortraitLockedLandscapeStage {
        NeckScreen(viewModel: NeckViewModel(stubChord: .am))
    }
}
