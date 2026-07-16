import SwiftUI
import UIKit

struct GuitarStringImageView: View {
    let assetName: String
    let stringIndex: Int

    var body: some View {
        Group {
            if let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                fallbackString
            }
        }
        .accessibilityLabel("Guitar string \(6 - stringIndex)")
    }

    private var fallbackString: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color(red: 0.62, green: 0.69, blue: 0.72),
                        Color.white.opacity(0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: .black.opacity(0.38), radius: 2, y: 1)
    }
}
