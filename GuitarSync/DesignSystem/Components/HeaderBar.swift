import SwiftUI

/// 화면 상단 공통 바 — 뒤로 · 제목 · (선택) 확인.
///
/// - Parameter onConfirm: `nil`이면 확인 버튼을 숨긴다. 확정할 게 없는 화면(기기 찾기 등)용.
struct HeaderBar: View {
    let title: String
    let onBack: () -> Void
    var onConfirm: (() -> Void)?

    var body: some View {
        ZStack {
            Text(title)
                .font(.gsHeading)
                .foregroundStyle(Color.gsTextPrimary)
                .underline()

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.gsFixed(28, weight: .semibold))
                        .foregroundStyle(Color.gsTextPrimary)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color.black.opacity(0.28)))
                        .overlay(Circle().stroke(Color.gsTextPrimary.opacity(0.20), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")

                Spacer()

                if let onConfirm {
                    Button(action: onConfirm) {
                        Image(systemName: "checkmark")
                            .font(.gsFixed(28, weight: .bold))
                            .foregroundStyle(Color.gsOnAccent.opacity(0.78))
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Color.gsTextPrimary.opacity(0.72)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("확정")
                }
            }
            .padding(.horizontal, Spacing.xl)
        }
        .frame(height: 86)
    }
}
