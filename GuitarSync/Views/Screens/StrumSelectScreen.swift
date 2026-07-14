import SwiftUI

struct StrumSelectScreen: View {
    let onBack: () -> Void
    let onConfirm: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(title: "스트로크 선택", onBack: onBack, onConfirm: onConfirm)
            HStack(alignment: .top, spacing: 32) {
                StrumColumn(title: "프리셋", showsCreate: false, onCreate: onCreate)
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 1)
                StrumColumn(title: "커스텀", showsCreate: true, onCreate: onCreate)
            }
            .padding(.horizontal, 30)
            .padding(.top, 8)
        }
    }
}

private struct StrumColumn: View {
    let title: String
    let showsCreate: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.68))
                if showsCreate {
                    Button(action: onCreate) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.78))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 10)

            ForEach(0..<4, id: \.self) { _ in
                StrumPatternRow()
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StrumPatternRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 9) {
                Text("♪")
                Text("♫")
                Text("♪")
                Text("♫")
            }
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(.white)

            HStack(spacing: 9) {
                Text("∩")
                Text("∩∨")
                Text("∩")
                Text("∩∨")
            }
            .font(.system(size: 15))
            .foregroundStyle(Color.white.opacity(0.34))
        }
        .frame(height: 68, alignment: .center)
        .padding(.leading, 14)
    }
}
