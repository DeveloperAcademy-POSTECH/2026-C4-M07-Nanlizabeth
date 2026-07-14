import SwiftUI

struct ChordProgressionScreen: View {
    @Binding var selectedRoot: String
    let onBack: () -> Void
    let onConfirm: () -> Void

    private let roots = ["ALL", "C", "D", "E", "F", "G", "A", "B"]
    private let chords = ["C", "C7", "Cm", "Cm7", "CM7", "D", "D7", "Dm", "Dm7", "E", "E7", "Em", "G"]

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(title: "코드 진행 생성", onBack: onBack, onConfirm: onConfirm)
            TimelineView()
                .padding(.horizontal, 44)
                .padding(.top, 44)

            rootSelector

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(76), spacing: 12), count: 9), spacing: 16) {
                    ForEach(filteredChords, id: \.self) { chord in
                        ChordCard(title: chord)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 44)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private var rootSelector: some View {
        HStack(spacing: 8) {
            ForEach(roots, id: \.self) { root in
                Button {
                    selectedRoot = root
                } label: {
                    Text(root)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 28)
                        .background(
                            Capsule()
                                .fill(selectedRoot == root ? Color.white.opacity(0.42) : Color.white.opacity(0.10))
                        )
                        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 44)
        .padding(.top, 44)
    }

    private var filteredChords: [String] {
        selectedRoot == "ALL" ? chords : chords.filter { $0.hasPrefix(selectedRoot) }
    }
}

private struct ChordCard: View {
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
            MiniChordDiagram()
        }
        .frame(width: 76, height: 106)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.24), lineWidth: 1))
        )
    }
}

private struct MiniChordDiagram: View {
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 54, height: 1)
                    .position(x: 27, y: CGFloat(i) * 8 + 4)
                Rectangle()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 1, height: 28)
                    .position(x: CGFloat(i) * 18, y: 16)
            }
            Circle().fill(.white).frame(width: 6, height: 6).position(x: 11, y: 11)
            Circle().fill(.white).frame(width: 6, height: 6).position(x: 29, y: 20)
            Circle().fill(.white).frame(width: 6, height: 6).position(x: 48, y: 20)
        }
        .frame(width: 54, height: 30)
    }
}
