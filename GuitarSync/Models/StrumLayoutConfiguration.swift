import CoreGraphics
import Foundation

struct StrumLayoutConfiguration: Equatable {
    var strumAxis: StrumAxis
    var reverseStringMapping: Bool
    var stringCount: Int

    init(
        strumAxis: StrumAxis = .y,
        reverseStringMapping: Bool = false,
        stringCount: Int = GuitarFingering.stringCount
    ) {
        self.strumAxis = strumAxis
        self.reverseStringMapping = reverseStringMapping
        self.stringCount = stringCount
    }
}

/// 터치 위치 → 줄 index. `band`는 터치 레이어 좌표계에서 **줄이 놓인 영역**이다.
/// 터치 레이어는 밴드보다 넓어(화면 전체) 밴드 **밖**을 짚으면 nil을 준다 —
/// 밖에서 시작해 안으로 긁어 들어오면 그제서야 가장자리 줄부터 훑힌다(호출 측 훑기 로직).
func stringIndex(
    from location: CGPoint,
    in band: CGRect,
    configuration: StrumLayoutConfiguration
) -> Int? {
    let axisLength = configuration.strumAxis == .x ? band.width : band.height
    let value = configuration.strumAxis == .x ? location.x - band.minX : location.y - band.minY

    guard axisLength > 0, value >= 0, value <= axisLength else {
        return nil
    }

    let rawIndex = Int((value / axisLength) * CGFloat(configuration.stringCount))
    let clampedIndex = min(max(rawIndex, 0), configuration.stringCount - 1)

    if configuration.reverseStringMapping {
        return configuration.stringCount - 1 - clampedIndex
    } else {
        return clampedIndex
    }
}
