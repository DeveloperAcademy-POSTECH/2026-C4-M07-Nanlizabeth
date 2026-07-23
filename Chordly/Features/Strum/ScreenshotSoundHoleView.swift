import SwiftUI

struct ScreenshotSoundHoleView: View {
    private let stringYs: [CGFloat] = [86, 142, 197, 252, 302, 352]
    private let fretXs: [CGFloat] = [644, 758, 844]
    let receivedFingerNumber: Int?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 560, height: 560)
                    .overlay(Circle().stroke(Color.white.opacity(0.46), lineWidth: 8))
                    .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 34))
                    .position(x: 374, y: 246)

                Rectangle()
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.12).opacity(0.92))
                    .frame(width: 330, height: proxy.size.height)
                    .position(x: 760, y: proxy.size.height / 2)

                ForEach(fretXs, id: \.self) { x in
                    Rectangle()
                        .fill(Color(red: 0.72, green: 0.78, blue: 0.85))
                        .frame(width: 9, height: 320)
                        .position(x: x, y: 220)
                }

                ForEach(stringYs, id: \.self) { y in
                    GuitarStringLine(thickness: y < 220 ? 4 : 3)
                        .frame(width: proxy.size.width, height: 7)
                        .position(x: proxy.size.width / 2, y: y)
                }

                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black)
                    .frame(width: 32, height: 104)
                    .overlay(
                        Circle()
                            .fill(Color.blue.opacity(0.55))
                            .frame(width: 7, height: 7)
                            .offset(y: 34)
                    )
                    .position(x: 844, y: 200)

                Rectangle()
                    .fill(Color.black.opacity(0.42))
                    .frame(width: 230, height: 5)
                    .position(x: 438, y: 391)

                if let receivedFingerNumber {
                    Text("\(receivedFingerNumber)")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 104, height: 104)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.58))
                                .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 2))
                        )
                        .position(x: 120, y: 120)
                }
            }
        }
    }
}
