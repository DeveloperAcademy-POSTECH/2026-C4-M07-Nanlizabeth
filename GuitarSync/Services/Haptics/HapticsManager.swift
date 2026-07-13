import UIKit

enum HapticsManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func mediumImpact() {
        impact(.medium)
    }
}
