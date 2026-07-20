import SwiftUI

/// 화면 1 — 첫 실행 안내. (SPEC 플로우 4 / ARCHITECTURE §3.10 · ROADMAP 태스크 U1)
///
/// 앱이 손댈 수 없는 두 가지(**볼륨·방해금지**)를 사용자가 직접 맞추도록 **안내**한다.
/// 나머지(무음 스위치·화면 꺼짐)는 앱이 알아서 처리하므로 다루지 않는다 (SPEC 플로우4 표).
///
/// - Note: 앱 첫 실행에만 뜨고, "시작하기"를 누르면 저장돼 이후 자동 스킵된다 (`AppRouter`).
struct OnboardingScreen: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var system = SystemSetupHelper()

    var body: some View {
        VStack(spacing: Spacing.lg) {
            header

            HStack(spacing: Spacing.md) {
                volumeCard
                doNotDisturbCard
            }
            .frame(maxHeight: .infinity)

            startButton
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(spacing: Spacing.xxs) {
            Text("연주 전에 두 가지만")
                .font(.gsTitle)
                .foregroundStyle(Color.gsTextPrimary)
            Text("진짜 기타 소리를 제대로 즐기려면 잠깐 확인해요")
                .font(.gsSubheadline)
                .foregroundStyle(Color.gsTextSecondary)
        }
    }

    // MARK: - 볼륨 카드

    private var volumeCard: some View {
        OnboardingCard(
            icon: system.isVolumeLow ? "speaker.slash.fill" : "speaker.wave.3.fill",
            iconTint: system.isVolumeLow ? Color.gsAccent : Color.gsTextPrimary,
            title: "볼륨 올리기",
            message: system.isVolumeLow
                ? "소리가 거의 안 들려요. 측면 버튼이나 아래 슬라이더로 올려주세요."
                : "적당해요. 더 키우고 싶으면 아래에서 조절해요."
        ) {
            VStack(spacing: Spacing.xs) {
                VolumeMeter(level: system.outputVolume)
                // 시스템 볼륨 슬라이더. ⚠️ 시뮬레이터에선 안 보인다 (볼륨 하드웨어 없음).
                SystemVolumeSlider()
                    .frame(height: 28)
            }
        }
    }

    // MARK: - 방해금지 카드

    private var doNotDisturbCard: some View {
        OnboardingCard(
            icon: "moon.fill",
            iconTint: Color.gsTextPrimary,
            title: "방해금지 켜기",
            message: "연주 중 알림이 끼어들지 않게 해요. 앱이 대신 못 켜므로 직접 켜주세요."
        ) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.down.forward")
                    .font(.gsCaption)
                    .foregroundStyle(Color.gsTextSecondary)
                Text("제어 센터 → 초승달(방해금지)")
                    .font(.gsCaption)
                    .foregroundStyle(Color.gsTextSecondary)
            }
            .padding(.top, Spacing.xxs)
        }
    }

    // MARK: - 시작

    private var startButton: some View {
        Button {
            router.completeOnboarding()
        } label: {
            Text("시작하기")
                .font(.gsHeadline)
                .foregroundStyle(Color.gsOnAccent)
                .frame(maxWidth: .infinity)
                .frame(height: HitTarget.minimum + 6)
                .background(Capsule().fill(Color.gsAccent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("온보딩 마치고 시작하기")
    }
}

/// 온보딩 카드 한 장 — 아이콘 + 제목 + 설명 + 자유 콘텐츠.
private struct OnboardingCard<Content: View>: View {
    let icon: String
    let iconTint: Color
    let title: String
    let message: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.gsHeading)
                    .foregroundStyle(iconTint)
                Text(title)
                    .font(.gsHeadline)
                    .foregroundStyle(Color.gsTextPrimary)
            }

            Text(message)
                .font(.gsSubheadline)
                .foregroundStyle(Color.gsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Spacing.xs)
            content
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.gsSurface)
        )
    }
}

/// 현재 볼륨을 막대로 보여준다. 시뮬레이터에서도 값이 있으면 그려진다.
private struct VolumeMeter: View {
    /// 0~1.
    let level: Float

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.3))
                Capsule()
                    .fill(level < 0.3 ? Color.gsAccent : Color.gsTextPrimary)
                    .frame(width: max(proxy.size.width * CGFloat(level), 4))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("현재 볼륨 \(Int(level * 100))퍼센트")
    }
}

#Preview("온보딩") {
    PortraitLockedLandscapeStage {
        OnboardingScreen()
            .environmentObject(AppRouter())
    }
}
