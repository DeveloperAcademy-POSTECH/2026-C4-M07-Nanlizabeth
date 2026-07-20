import SwiftUI

struct ScreenshotFretboardView: View {
    private let stringYs: [CGFloat] = [100, 156, 212, 266, 320, 372]
    private let fretXs: [CGFloat] = [16, 148, 306, 474, 650, 832]
    let selectedChord: GuitarChord?
    let onChordTap: (GuitarChord) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.12))
                    .frame(height: 310)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2 + 14)

                ForEach(fretXs, id: \.self) { x in
                    Rectangle()
                        .fill(Color(red: 0.72, green: 0.78, blue: 0.85))
                        .frame(width: x == 832 ? 28 : 9, height: 316)
                        .position(x: x, y: proxy.size.height / 2 + 14)
                }

                ForEach(stringYs, id: \.self) { y in
                    GuitarStringLine(thickness: y < 220 ? 4 : 3)
                        .frame(width: proxy.size.width, height: 7)
                        .position(x: proxy.size.width / 2, y: y)
                }

                Circle()
                    .fill(Color(red: 0.88, green: 0.92, blue: 0.97))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color(red: 0.46, green: 0.53, blue: 0.62), lineWidth: 2))
                    .position(x: 82, y: 238)

                Circle()
                    .fill(Color(red: 0.88, green: 0.92, blue: 0.97))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color(red: 0.46, green: 0.53, blue: 0.62), lineWidth: 2))
                    .position(x: 390, y: 238)

                ForEach(chordMarkers) { marker in
                    Button {
                        onChordTap(marker.chord)
                    } label: {
                        Text(marker.chord.rawValue)
                            .font(.system(size: marker.chord.rawValue.count > 1 ? 15 : 17, weight: .bold))
                            .foregroundStyle(marker.chord == selectedChord ? .black : .white)
                            .frame(width: 42, height: 34)
                            .background(
                                Capsule()
                                    .fill(marker.chord == selectedChord ? Color.white : Color.black.opacity(0.72))
                            )
                            .overlay(Capsule().stroke(Color.white.opacity(0.86), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .position(marker.position)
                }

                Rectangle()
                    .fill(Color.black.opacity(0.42))
                    .frame(height: 14)
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 8)
            }
        }
    }

    private var chordMarkers: [ChordMarker] {
        [
            ChordMarker(chord: .c, position: CGPoint(x: 214, y: 156)),
            ChordMarker(chord: .g, position: CGPoint(x: 306, y: 212)),
            ChordMarker(chord: .d, position: CGPoint(x: 474, y: 266)),
            ChordMarker(chord: .am, position: CGPoint(x: 650, y: 320))
        ]
    }
}

private struct ChordMarker: Identifiable {
    let chord: GuitarChord
    let position: CGPoint

    var id: GuitarChord { chord }
}
