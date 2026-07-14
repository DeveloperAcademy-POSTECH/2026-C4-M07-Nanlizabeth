import CoreGraphics

enum StrumAxis: String, CaseIterable, Codable {
    case x
    case y
}

func axisValue(from location: CGPoint, axis: StrumAxis) -> CGFloat {
    switch axis {
    case .x:
        return location.x
    case .y:
        return location.y
    }
}
