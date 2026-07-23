import UIKit

enum DeviceInfoProvider {
    static var currentDeviceType: DeviceType {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return .iPhone
        case .pad:
            return .iPad
        default:
            return .unknown
        }
    }

    static func defaultRole(for deviceType: DeviceType) -> DeviceRole {
        switch deviceType {
        case .iPhone:
            return .chordAndStrum
        case .iPad:
            return .strumOnly
        case .unknown:
            return .strumOnly
        }
    }
}
