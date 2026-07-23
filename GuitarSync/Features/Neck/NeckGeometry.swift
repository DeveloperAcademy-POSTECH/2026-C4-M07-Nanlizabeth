import CoreGraphics

/// 기타넥 화면의 좌표 규약. (ROADMAP 태스크 U2 · Figma HI-FI `코드 모드 - 기본`)
///
/// **화면 없이 검증할 수 있게 순수 계산만 둔다.** 터치를 `FretPress`로 바꾸는 규칙이 여기 전부
/// 있고, 뷰는 이 값을 읽어 그리기만 한다. 좌표를 고칠 일이 생기면 **이 파일 하나만** 고친다.
///
/// ## 방향 규약 (헷갈리기 쉬운 곳)
///
/// - **세로**: 위가 6번줄(가장 굵은 저음 E, `stringIndex 0`) → 아래가 1번줄(고음 E, `stringIndex 5`).
///   ARCHITECTURE §5의 전 팀 공통 규약과 같다.
/// - **가로**: **오른쪽 끝이 너트**이고, 왼쪽으로 갈수록 프렛 번호가 올라간다.
///   기타를 눕혀 든 모습이라 실제 악기와 방향이 같다.
///
/// ```
///   6번줄(저음) ────────────────────────────────  ← stringIndex 0
///                 5프렛   4    3    2    1  ┃너트
///   1번줄(고음) ────────────────────────────────  ← stringIndex 5
/// ```
///
/// - Note: 좌표값은 Figma HI-FI 프레임(874×402)에서 그대로 딴 것이다. 스테이지가 이 도화지를
///   보장하므로(ARCHITECTURE §2.5) 기기 분기는 필요 없다.
enum NeckGeometry {
    /// 이 좌표들이 전제하는 도화지.
    static let stage = LayoutTokens.phoneStage

    /// 줄의 세로 위치. **배열 인덱스가 곧 `stringIndex`.**
    static let stringYs: [CGFloat] = [100, 156, 212, 266, 320, 372]

    /// 프렛 경계선의 가로 위치. **첫 값이 너트**, 이후 왼쪽으로 1·2·3…프렛의 경계다.
    ///
    /// 간격이 왼쪽으로 갈수록 좁아지는 건 실제 기타와 같다 (음이 높아질수록 프렛이 촘촘해짐).
    ///
    /// - Note: `iPhoneNeckBackground` 이미지(2622×1206 = 스테이지 3배)에서 프렛 바 중심을 측정해
    ///   맞춘 값이다. 인레이(3·5프렛) 중심과도 1px 이내로 일치한다. 배경 이미지를 바꾸면 이 값도
    ///   다시 맞춰야 짚는 점·목표 표식이 그림 속 프렛과 어긋나지 않는다.
    static let fretBoundaryXs: [CGFloat] = [862, 683, 506, 338, 181, 48]

    /// 지판(어두운 판)의 세로 범위. **이 밖의 터치는 무시한다** — 위쪽 컨트롤 바를 누르다가
    /// 소리가 나면 안 되기 때문이다.
    static let boardTop: CGFloat = 68
    static let boardBottom: CGFloat = 396

    /// 너트 막대의 두께. 일반 프렛보다 굵다.
    static let nutWidth: CGFloat = 28
    /// 일반 프렛 막대의 두께.
    static let fretWidth: CGFloat = 9

    /// 포지션 마크(점)를 찍는 프렛. 실제 기타와 같은 자리다.
    static let inlayFrets: [Int] = [3, 5]

    /// 포지션 마크 점의 지름.
    static let inlayDiameter: CGFloat = 26

    /// 짚은 자리 표시의 지름. 손끝보다 살짝 크게 잡아 **손가락에 가리지 않게** 한다.
    static let pressMarkerDiameter: CGFloat = 34

    /// 짚을 수 있는 프렛 수. 경계선이 n개면 칸은 n-1개다.
    static var fretCount: Int { max(fretBoundaryXs.count - 1, 0) }

    /// 지판의 세로 한가운데. 포지션 마크가 놓이는 높이.
    static var boardCenterY: CGFloat {
        guard let first = stringYs.first, let last = stringYs.last else { return 0 }
        return (first + last) / 2
    }

    // MARK: - 터치 → 의미

    /// 터치 한 점 → "몇 번 줄 몇 프렛". 지판 밖이면 `nil`.
    static func press(at point: CGPoint) -> FretPress? {
        guard let stringIndex = stringIndex(atY: point.y),
              let fret = fret(atX: point.x)
        else {
            return nil
        }

        return FretPress(stringIndex: stringIndex, fret: fret)
    }

    /// 접촉 반지름이 클수록 세로로 더 넓은 줄 범위를 덮는 정도. (바레 감도)
    /// 값이 클수록 손가락을 살짝만 눕혀도 이웃 줄이 함께 잡힌다.
    static let barreRadiusScale: CGFloat = 1.4

    /// 터치 한 개(중심 + 접촉 반지름) → 짚은 칸들. **넓게 누르면(바레) 세로로 인접한 여러 줄**을
    /// 같은 프렛으로 함께 짚은 것으로 본다. (docs/PLAN-chord-drill 개선 — 한 손가락 바레 입력)
    ///
    /// 접촉이 작으면(지문 하나) 가장 가까운 줄 하나만 — 기존 동작과 같다(회귀 없음).
    static func presses(at point: CGPoint, majorRadius: CGFloat) -> [FretPress] {
        guard point.y >= boardTop, point.y <= boardBottom, let fret = fret(atX: point.x) else {
            return []
        }

        let halfBand = majorRadius * barreRadiusScale
        var covered = stringYs.indices.filter { abs(stringYs[$0] - point.y) <= halfBand }
        // 접촉이 작아 아무 줄도 안 걸리면, 가장 가까운 줄 하나로 친다.
        if covered.isEmpty, let nearest = stringIndex(atY: point.y) {
            covered = [nearest]
        }
        return covered.map { FretPress(stringIndex: $0, fret: fret) }
    }

    /// 세로 위치 → 줄 번호.
    ///
    /// **줄 위를 정확히 짚을 필요는 없다.** 가장 가까운 줄로 쳐서 줄 사이 공간을 반씩 나눠 갖는다 —
    /// 실제 연주도 선이 아니라 칸을 누르고, 손끝은 줄보다 훨씬 두껍다.
    static func stringIndex(atY y: CGFloat) -> Int? {
        guard y >= boardTop, y <= boardBottom else { return nil }

        var nearest: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for (index, stringY) in stringYs.enumerated() {
            let distance = abs(stringY - y)
            if distance < bestDistance {
                bestDistance = distance
                nearest = index
            }
        }

        return nearest
    }

    /// 가로 위치 → 프렛 번호(1부터). 너트 바깥이거나 지판 끝을 넘으면 `nil`.
    ///
    /// 경계선 위(정확히 프렛 막대 위)를 눌렀을 때는 **오른쪽 칸**, 즉 낮은 프렛으로 친다.
    static func fret(atX x: CGFloat) -> Int? {
        guard fretCount > 0 else { return nil }

        for fret in 1...fretCount {
            let rightEdge = fretBoundaryXs[fret - 1]
            let leftEdge = fretBoundaryXs[fret]
            if x <= rightEdge, x > leftEdge {
                return fret
            }
        }

        return nil
    }

    // MARK: - 의미 → 좌표 (그리기용)

    /// 짚은 자리 표시를 그릴 중심점. 칸의 가로 한가운데 × 그 줄의 높이.
    static func center(stringIndex: Int, fret: Int) -> CGPoint? {
        guard stringYs.indices.contains(stringIndex),
              let x = fretCenterX(fret)
        else {
            return nil
        }

        return CGPoint(x: x, y: stringYs[stringIndex])
    }

    /// 프렛 칸의 가로 한가운데.
    static func fretCenterX(_ fret: Int) -> CGFloat? {
        guard fretCount > 0, (1...fretCount).contains(fret) else { return nil }
        return (fretBoundaryXs[fret - 1] + fretBoundaryXs[fret]) / 2
    }

    /// 6번 저음줄부터 1번 고음줄까지의 굵기.
    static let stringThicknesses: [CGFloat] = [
        5.0,
        4.5,
        4.0,
        3.2,
        2.6,
        2.0,
    ]

    /// 줄의 굵기. 저음줄에서 고음줄로 갈수록 단계적으로 얇아진다.
    static func stringThickness(_ stringIndex: Int) -> CGFloat {
        guard stringThicknesses.indices.contains(stringIndex) else { return 3 }
        return stringThicknesses[stringIndex]
    }

    // MARK: - 짚은 자리 표식 (원 / 바레 타원)

    /// 개방현(○)·뮤트(✕) 힌트를 찍는 가로 위치 — 너트 바로 오른쪽 바깥.
    static let openMuteHintX: CGFloat = 858

    /// 짚은 자리를 그릴 표식 하나. 한 프렛에서 **인접한 여러 줄**이면 타원(바레), 한 줄이면 원.
    struct FingerMarker: Equatable, Identifiable {
        let id: String
        let center: CGPoint
        let size: CGSize
        /// 여러 줄에 걸친 바레(타원)인가. 아니면 원(가로세로 같음).
        let isBarre: Bool
        /// 손가락 번호(1~4). `0`이면 번호를 표시하지 않는다 (짚기 피드백 등).
        var finger: Int = 0
    }

    /// 줄→프렛 매핑(프렛 1 이상만)을 원/바레 표식으로 바꾼다. (docs/PLAN-chord-drill 개선)
    ///
    /// - 같은 프렛에서 **연속된 줄**은 하나의 타원(바레)으로 묶는다 — F 코드처럼 손가락 하나로
    ///   여러 줄을 누르는 모습.
    /// - 한 줄만이면 원. (원은 폭·높이가 같은 캡슐이라 자연히 동그랗다.)
    static func fingerMarkers(frettedByString: [Int: Int]) -> [FingerMarker] {
        var byFret: [Int: [Int]] = [:]
        for (stringIndex, fret) in frettedByString where fret >= 1 {
            byFret[fret, default: []].append(stringIndex)
        }

        var markers: [FingerMarker] = []
        for (fret, strings) in byFret {
            guard let x = fretCenterX(fret) else { continue }
            for run in contiguousRuns(strings.sorted()) {
                guard stringYs.indices.contains(run.start), stringYs.indices.contains(run.end) else { continue }
                let yTop = stringYs[run.start]
                let yBottom = stringYs[run.end]
                let isBarre = run.end > run.start
                markers.append(
                    FingerMarker(
                        id: "\(fret)-\(run.start)-\(run.end)",
                        center: CGPoint(x: x, y: (yTop + yBottom) / 2),
                        size: CGSize(
                            width: pressMarkerDiameter,
                            height: isBarre ? (yBottom - yTop) + pressMarkerDiameter : pressMarkerDiameter
                        ),
                        isBarre: isBarre
                    )
                )
            }
        }
        return markers
    }

    /// **코드 다이어그램용 표식** — 손가락 번호를 달아 "어느 줄을 몇 번 손가락으로" 안내한다.
    /// (docs/PLAN-chord-drill 개선 — 운지 손가락 안내)
    ///
    /// - **바레(타원)**는 *같은 손가락*이 **연속된 3줄 이상**을 누를 때만 만든다.
    ///   F처럼 검지가 6번줄과 1·2번줄에 떨어져 걸치면(가운데는 다른 손가락이 위에서 누름)
    ///   연속 구간이 2줄 이하라 **원 여러 개**로 나뉘어, 각 줄을 또렷이 짚도록 안내한다.
    /// - `frets`는 6개 운지(`-1`뮤트·`0`개방·`1~`프렛), `fingers`는 6개 손가락(`0`안짚음·`1~4`).
    static func chordDiagramMarkers(frets: [Int], fingers: [Int]) -> [FingerMarker] {
        struct Key: Hashable { let fret: Int; let finger: Int }

        var byKey: [Key: [Int]] = [:]
        for index in stringYs.indices where frets.indices.contains(index) && frets[index] >= 1 {
            let finger = fingers.indices.contains(index) ? fingers[index] : 0
            byKey[Key(fret: frets[index], finger: finger), default: []].append(index)
        }

        var markers: [FingerMarker] = []
        for (key, strings) in byKey {
            guard let x = fretCenterX(key.fret) else { continue }
            for run in contiguousRuns(strings.sorted()) {
                let spanned = run.end - run.start + 1
                if spanned >= 3 {
                    // 같은 손가락이 3줄 이상 → 바레 타원 하나.
                    let yTop = stringYs[run.start]
                    let yBottom = stringYs[run.end]
                    markers.append(
                        FingerMarker(
                            id: "barre-\(key.fret)-\(key.finger)-\(run.start)",
                            center: CGPoint(x: x, y: (yTop + yBottom) / 2),
                            size: CGSize(width: pressMarkerDiameter, height: (yBottom - yTop) + pressMarkerDiameter),
                            isBarre: true,
                            finger: key.finger
                        )
                    )
                } else {
                    // 1~2줄 → 각 줄을 원으로 (F의 바깥 두 줄 등).
                    for stringIndex in run.start...run.end {
                        markers.append(
                            FingerMarker(
                                id: "dot-\(key.fret)-\(key.finger)-\(stringIndex)",
                                center: CGPoint(x: x, y: stringYs[stringIndex]),
                                size: CGSize(width: pressMarkerDiameter, height: pressMarkerDiameter),
                                isBarre: false,
                                finger: key.finger
                            )
                        )
                    }
                }
            }
        }
        return markers
    }

    /// 정렬된 정수 목록을 **연속 구간**들로 나눈다. 예: `[0,1,2,4,5]` → `[(0,2),(4,5)]`.
    static func contiguousRuns(_ sorted: [Int]) -> [(start: Int, end: Int)] {
        guard let first = sorted.first else { return [] }
        var runs: [(start: Int, end: Int)] = []
        var start = first
        var prev = first
        for value in sorted.dropFirst() {
            if value == prev + 1 {
                prev = value
            } else {
                runs.append((start, prev))
                start = value
                prev = value
            }
        }
        runs.append((start, prev))
        return runs
    }
}
