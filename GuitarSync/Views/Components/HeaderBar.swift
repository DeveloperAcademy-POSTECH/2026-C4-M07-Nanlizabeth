import SwiftUI

struct HeaderBar: View {
    let title: String
    let onBack: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .underline()

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color.black.opacity(0.28)))
                        .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onConfirm) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black.opacity(0.78))
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color.white.opacity(0.72)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
        }
        .frame(height: 86)
    }
}
