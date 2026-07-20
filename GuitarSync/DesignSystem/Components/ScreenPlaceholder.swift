import SwiftUI

/// 아직 안 만든 화면 자리. (ROADMAP 태스크 F3)
///
/// 라우터에 **모든 화면이 미리 등록돼 있어야** 각자 자기 화면 파일만 채우면 되는 상태가 된다.
/// 이 자리를 진짜 화면으로 바꾸는 게 U 레인의 일이다.
///
/// ```swift
/// // 채우기 전
/// var body: some View { ScreenPlaceholder(route: .onboarding, task: "U1") }
///
/// // 채운 뒤 — 이 줄을 지우고 진짜 화면을 그리면 끝
/// ```
struct ScreenPlaceholder: View {
    let route: AppRoute
    /// 이 화면을 만드는 ROADMAP 태스크 번호 ("U1", "U6" …).
    let task: String
    /// 화면 담당에게 남기는 힌트 (관련 계약, 주의점).
    var hint: String?

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text(route.title)
                .font(.gsTitle)
                .foregroundStyle(Color.gsTextPrimary)

            VStack(spacing: Spacing.xxs + 2) {
                Text("아직 만들지 않은 화면입니다")
                    .font(.gsBody)
                    .foregroundStyle(Color.gsTextSecondary)

                Text("담당 태스크 \(task)")
                    .font(.gsCaption)
                    .foregroundStyle(Color.gsTextTertiary)

                if let hint {
                    Text(hint)
                        .font(.gsLabel)
                        .foregroundStyle(Color.gsTextTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.xxs)
                }
            }

            if router.canGoBack {
                Button("뒤로") { router.back() }
                    .font(.gsButton)
                    .foregroundStyle(Color.gsTextPrimary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .frame(minHeight: HitTarget.minimum)
                    .background(Capsule().fill(.white.opacity(0.14)))
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
