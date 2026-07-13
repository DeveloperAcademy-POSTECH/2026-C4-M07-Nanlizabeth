import SwiftUI

enum DeviceType: String {
    case iPhone
    case iPad
    case unknown

    var displayName: String {
        switch self {
        case .iPhone: return "iPhone"
        case .iPad: return "iPad"
        case .unknown: return "Unknown"
        }
    }
}
