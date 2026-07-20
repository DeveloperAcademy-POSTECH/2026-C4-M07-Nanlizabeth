import SwiftUI

struct TimelineView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.90))
                    .frame(height: 4)
                    .position(x: proxy.size.width / 2, y: 24)

                Text("4\n4")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white)
                    .lineSpacing(-4)
                    .position(x: 14, y: 24)

                ForEach([0.0, 0.25, 0.50, 0.75, 1.0], id: \.self) { ratio in
                    Rectangle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 4, height: 44)
                        .position(x: max(2, proxy.size.width * ratio), y: 24)
                }
            }
        }
        .frame(height: 48)
    }
}
