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
        VStack(spacing: 16) {
            Text(route.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 6) {
                Text("아직 만들지 않은 화면입니다")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))

                Text("담당 태스크 \(task)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))

                if let hint {
                    Text(hint)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }

            if router.canGoBack {
                Button("뒤로") { router.back() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white.opacity(0.14)))
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
