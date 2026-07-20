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
    static let fretBoundaryXs: [CGFloat] = [832, 650, 474, 306, 148, 16]

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

    /// 줄의 굵기. 저음줄일수록 굵다 — 실제 기타와 같다.
    static func stringThickness(_ stringIndex: Int) -> CGFloat {
        stringIndex < 3 ? 4 : 3
    }
}
