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

    /// 목표 코드의 손가락 번호(줄마다 하나). 있으면 고스트 위에 번호를 함께 안내한다.
    var targetFingers: [Int] = []

    /// 넥 위에 얹은 컨트롤(포지션 바 등)의 영역 — 이 안의 터치는 프렛 짚기로 안 받는다.
    /// 자유연주(모드 A)가 포지션 슬라이더 자리를 넣는다. 드릴은 비운다.
    var extraExcludedRegions: [CGRect] = []

    var body: some View {
        ZStack {
            Image("iPhoneNeckBackground")
                .resizable()
                .scaledToFill()
                .frame(width: NeckGeometry.stage.width, height: NeckGeometry.stage.height)
                .clipped()
            inlays
            strings
            targetMarkers
            pressMarkers
            fretNumbers
            positionBadge

            // 맨 위에 깔아 손가락을 전부 받는다. 접촉 반지름까지 받아, 넓게 누르면(바레) 여러 줄로 편다.
            // 지판 밖 터치는 `NeckGeometry.presses(at:majorRadius:)`가 걸러낸다.
            MultiTouchLayer(
                excludedHitRegions: [InstrumentControlHitRegion.topBar] + extraExcludedRegions,
                onSamplesChanged: { samples in
                    let presses = samples.values.flatMap {
                        NeckGeometry.presses(at: $0.location, majorRadius: $0.majorRadius)
                    }
                    viewModel.pressesChanged(Set(presses))
                }
            )
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

    private var stageCenterX: CGFloat { NeckGeometry.stage.width / 2 }

    // MARK: - 레이어

    /// 실제 기타처럼 특정 프렛에 찍는 포지션 마크 (인레이). 12프렛은 두 개.
    private static let inlayFrets: Set<Int> = [3, 5, 7, 9, 12]

    /// 프렛 칸마다 **몇 번째 프렛인지** 숫자로 (윗단). 포지션을 옮기면 그 값이 따라 바뀐다.
    private var fretNumbers: some View {
        ForEach(1...NeckGeometry.fretCount, id: \.self) { space in
            if let x = NeckGeometry.fretCenterX(space) {
                Text("\(space + viewModel.fretOffset)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.gsTextSecondary)
                    .position(x: x, y: NeckGeometry.boardTop + 14)
            }
        }
    }

    /// 인레이(포지션 마크). **실제 프렛 기준**으로 3·5·7·9·12프렛에 동적으로 찍는다.
    /// 배경 이미지엔 인레이가 없으므로(953-2623 넥) 포지션을 옮기면 이 점들도 함께 이동한다.
    private var inlays: some View {
        ForEach(1...NeckGeometry.fretCount, id: \.self) { space in
            let actualFret = space + viewModel.fretOffset
            if Self.inlayFrets.contains(actualFret), let x = NeckGeometry.fretCenterX(space) {
                inlayDots(atFret: actualFret, x: x)
            }
        }
    }

    /// 인레이 점. 12프렛은 위아래 두 개, 나머지는 한가운데 한 개 — 실제 기타와 같다.
    @ViewBuilder
    private func inlayDots(atFret fret: Int, x: CGFloat) -> some View {
        let dot = Circle()
            .fill(Color.gsTextPrimary.opacity(0.85))
            .overlay(Circle().stroke(Color.gsHardware, lineWidth: 1.5))
            .frame(width: NeckGeometry.inlayDiameter, height: NeckGeometry.inlayDiameter)
        if fret == 12 {
            dot.position(x: x, y: NeckGeometry.stringYs[1])
            dot.position(x: x, y: NeckGeometry.stringYs[4])
        } else {
            dot.position(x: x, y: NeckGeometry.boardCenterY)
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
            ForEach(NeckGeometry.chordDiagramMarkers(frets: target.frets, fingers: targetFingers)) { marker in
                Capsule()
                    .fill(Color.gsAccent.opacity(0.16))
                    .overlay(Capsule().stroke(Color.gsAccent, lineWidth: 2.5))
                    .frame(width: marker.size.width, height: marker.size.height)
                    .overlay(fingerLabel(marker))
                    .position(marker.center)
            }
            ForEach(Array(target.frets.enumerated()), id: \.offset) { index, fret in
                openMuteHint(stringIndex: index, fret: fret)
            }
        }
    }

    /// 표식 안에 그릴 손가락 번호. `0`이면 아무것도 안 그린다.
    ///
    /// 숫자 **뒤에만 어두운 칩**(넥 색)을 깔아, 칩이 그 자리 줄을 가려서 안 짚은 상태에서도
    /// 숫자가 또렷이 읽힌다. 칩은 어두운 색이라 짚었을 때의 라임 피드백과 겹치지 않는다.
    /// 바레(타원)면 위쪽에 한 번만, 원이면 한가운데에 둔다.
    @ViewBuilder
    private func fingerLabel(_ marker: NeckGeometry.FingerMarker) -> some View {
        if marker.finger > 0 {
            ZStack {
                Circle()
                    .fill(Color.gsNeckSurface)
                    .overlay(Circle().stroke(Color.gsAccent.opacity(0.5), lineWidth: 1))
                    .frame(width: 22, height: 22)
                Text("\(marker.finger)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.gsAccent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: marker.isBarre ? .top : .center)
            .padding(.top, marker.isBarre ? 5 : 0)
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

    /// 넥이 사운드홀 쪽으로 옮겨졌을 때, 지금 화면 첫 칸이 몇 프렛인지 알려주는 배지.
    /// (포지션 0 = 기존 1프렛 위치일 땐 숨긴다.)
    @ViewBuilder
    private var positionBadge: some View {
        if viewModel.fretOffset > 0 {
            Text("\(viewModel.fretOffset + 1)fr")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.gsOnAccent)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.gsAccent))
                .position(x: NeckGeometry.openMuteHintX, y: 40)
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

}

#Preview("기타넥 — Mock (아무 데나 눌러도 Am)") {
    PortraitLockedLandscapeStage {
        NeckScreen(viewModel: NeckViewModel(stubChord: .am))
    }
}
