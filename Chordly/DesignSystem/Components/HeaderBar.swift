import SwiftUI

/// 화면 상단 공통 바 — 뒤로 · 제목 · (선택) 확인.
///
/// - Parameter onConfirm: `nil`이면 확인 버튼을 숨긴다. 확정할 게 없는 화면(기기 찾기 등)용.
struct HeaderBar: View {
    @Environment(\.landscapeStageSafeAreaInsets) private var stageSafeArea

    let title: String
    let onBack: () -> Void
    var onConfirm: (() -> Void)?
    var highlightsConfirm = false

    var body: some View {
        ZStack {
            Text(title)
                .font(.gsHeading)
                .bold()
                .foregroundStyle(Color.gsTextPrimary)

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
                    // 확정 버튼은 형광색 — HI-FI `스트로크 선택 페이지` 기준.
                    // (이 컴포넌트를 쓰는 3개 화면에 함께 반영된다)
                    Button(action: onConfirm) {
                        Image(systemName: "checkmark")
                            .font(.gsFixed(28, weight: .bold))
                            .foregroundStyle(Color.gsOnAccent)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Color.gsAccent))
                    }
                    .buttonStyle(.plain)
                    .tutorialPulseHighlight(highlightsConfirm, cornerRadius: 23)
                    .accessibilityLabel("확정")
                }
            }
            .padding(.leading, max(Spacing.xl, stageSafeArea.leading))
            .padding(.trailing, max(Spacing.xl, stageSafeArea.trailing))
        }
        .frame(height: 86)
        .padding(.top, stageSafeArea.top)
    }
}
