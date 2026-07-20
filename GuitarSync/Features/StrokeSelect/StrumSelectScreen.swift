import SwiftUI

/// 화면 4 — 스트로크(주법) 선택. (SPEC §6 · ROADMAP 태스크 U4)
///
/// - Note: **커스텀 주법은 없습니다** (2026-07-20 결정). 프리셋 목록만 보여줍니다.
///   사용자가 직접 만드는 건 코드진행뿐입니다.
/// - Note: 이 화면은 **iPhone 전용**입니다. iPad는 항상 직접 긁으므로 자동 주법을 고를 일이 없습니다.
struct StrumSelectScreen: View {
    let onBack: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(title: "스트로크 선택", onBack: onBack, onConfirm: onConfirm)

            // TODO(U4): 더미 4행 → StrumPatternLibrary.presets 구독으로 교체
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    StrumPatternRow()
                    Rectangle()
                        .fill(Color.gsSeparator)
                        .frame(height: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xs)
        }
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
            // 악보 기호는 크기가 곧 의미라 다이내믹 타입을 끈다.
            .font(.gsFixed(25, weight: .semibold))
            .foregroundStyle(Color.gsTextPrimary)

            HStack(spacing: 9) {
                Text("∩")
                Text("∩∨")
                Text("∩")
                Text("∩∨")
            }
            .font(.gsSubheadline)
            .foregroundStyle(Color.gsTextPrimary.opacity(0.34))
        }
        .frame(height: 68, alignment: .center)
        .padding(.leading, Spacing.sm)
    }
}
