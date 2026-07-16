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

func stringIndex(
    from location: CGPoint,
    in size: CGSize,
    configuration: StrumLayoutConfiguration
) -> Int? {
    let axisLength = configuration.strumAxis == .x ? size.width : size.height
    let value = configuration.strumAxis == .x ? location.x : location.y

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
