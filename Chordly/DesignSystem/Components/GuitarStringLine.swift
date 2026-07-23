import SwiftUI

struct GuitarStringLine: View {
    let thickness: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.30))
                .frame(height: thickness + 3)
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .frame(height: 1)
                .offset(y: -2)
            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(height: thickness)
            Rectangle()
                .fill(Color.black.opacity(0.28))
                .frame(height: 1)
                .offset(y: 1)
        }
    }
}
