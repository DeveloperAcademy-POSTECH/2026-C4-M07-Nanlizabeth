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

    /// **짚어야 할 목표 코드.** 있으면 넥 위에 라임 고스트로 "여기를 짚어라"를 표시한다.
    /// (코드 드릴이 넣는다. 자유연주 모드 A는 `nil` — 오버레이 없음.)
    var targetFingering: GuitarFingering? = nil

    var body: some View {
        ZStack {
            board
            fretBars
            inlays
            strings
            targetMarkers
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
            // 방금 울린 세기(0~1). 없으면 0 = 가만히.
            let intensity = viewModel.stringIntensity[index] ?? 0

            GuitarStringLine(thickness: thickness)
                .frame(width: NeckGeometry.stage.width, height: thickness + 3)
                // 세게 칠수록 굵게 부풀었다 가라앉는다 — 떨림의 착시.
                .scaleEffect(x: 1, y: 1 + intensity * 0.9, anchor: .center)
                .position(x: stageCenterX, y: y)
                // 세기에 비례한 글로우.
                .shadow(color: .white.opacity(intensity * 0.85), radius: 4 + intensity * 8)
        }
        .animation(.easeOut(duration: 0.16), value: viewModel.stringIntensity)
    }

    /// 지금 짚고 있는 자리. **줄마다 사운드홀에 가까운 프렛(가장 높은 번호) 하나만** 표시한다 —
    /// 실제 기타에서 한 줄에 여러 곳을 눌러도 몸통에 가까운 쪽만 소리 나는 것과 같다.
    /// 같은 프렛에서 인접한 여러 줄을 짚으면 원이 아니라 **타원(바레)**으로 묶어 보여준다.
    private var pressMarkers: some View {
        ForEach(NeckGeometry.fingerMarkers(frettedByString: pressedFretted)) { marker in
            Capsule()
                .fill(Color.gsAccent)
                .overlay(Capsule().stroke(Color.gsOnAccent.opacity(0.4), lineWidth: 2))
                .frame(width: marker.size.width, height: marker.size.height)
                .position(marker.center)
        }
        .animation(.easeOut(duration: 0.12), value: pressedFretted)
    }

    /// 짚어야 할 목표 코드 오버레이 — 라임 고스트(테두리). 짚어야 할 프렛은 원/바레로,
    /// 개방현은 ○, 뮤트는 ✕로 너트 바깥에 힌트를 준다.
    @ViewBuilder
    private var targetMarkers: some View {
        if let target = targetFingering {
            ForEach(NeckGeometry.fingerMarkers(frettedByString: Self.frettedByString(target))) { marker in
                Capsule()
                    .fill(Color.gsAccent.opacity(0.14))
                    .overlay(Capsule().stroke(Color.gsAccent, lineWidth: 2.5))
                    .frame(width: marker.size.width, height: marker.size.height)
                    .position(marker.center)
            }
            ForEach(Array(target.frets.enumerated()), id: \.offset) { index, fret in
                openMuteHint(stringIndex: index, fret: fret)
            }
        }
    }

    /// 개방현(○)·뮤트(✕) 힌트 하나. 프렛을 짚는 줄은 표시하지 않는다.
    @ViewBuilder
    private func openMuteHint(stringIndex: Int, fret: Int) -> some View {
        if NeckGeometry.stringYs.indices.contains(stringIndex) {
            let y = NeckGeometry.stringYs[stringIndex]
            if fret == 0 {
                Circle()
                    .stroke(Color.gsAccent, lineWidth: 2)
                    .frame(width: 15, height: 15)
                    .position(x: NeckGeometry.openMuteHintX, y: y)
            } else if fret < 0 {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.gsTextSecondary)
                    .position(x: NeckGeometry.openMuteHintX, y: y)
            }
        }
    }

    /// 지금 짚은 것 중 **줄마다 가장 높은 프렛**만 남긴다 (프렛 1 이상). 소리 규칙과 같은 기준.
    private var pressedFretted: [Int: Int] {
        var result: [Int: Int] = [:]
        for press in viewModel.activePresses where press.fret >= 1 {
            result[press.stringIndex] = max(result[press.stringIndex] ?? 0, press.fret)
        }
        return result
    }

    /// 운지 → 줄:프렛 매핑(프렛 1 이상만). 목표 오버레이용.
    private static func frettedByString(_ fingering: GuitarFingering) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for (index, fret) in fingering.frets.enumerated() where fret >= 1 {
            result[index] = fret
        }
        return result
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
