import SwiftUI

/// 화면 8 — 연결 가이드. (SPEC 플로우 3 / ARCHITECTURE §3.8 · ROADMAP 태스크 U7)
///
/// - Important: ⚠️ **HI-FI 디자인이 없어 토큰만으로 만든 초안입니다.**
///   구조를 일부러 단순하게 뒀으니, 디자인이 나오면 이 파일과 `PeerGuideStep.all(...)`의
///   문구만 갈아끼우면 됩니다.
struct PeerGuideScreen: View {
    @Environment(\.landscapeStageSafeAreaInsets) private var stageSafeArea
    @EnvironmentObject private var router: AppRouter
    @ObservedObject var viewModel: PeerConnectViewModel

    var body: some View {
        let step = viewModel.guideSteps[min(viewModel.guideStep, viewModel.guideSteps.count - 1)]

        VStack(spacing: 0) {
            // 상단: 스킵
            HStack {
                Spacer()
                Button("건너뛰기") { finish() }
                    .font(.gsSubheadline)
                    .foregroundStyle(Color.gsTextSecondary)
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            }
            .stageSafeAreaHorizontalPadding(minimum: Spacing.lg)

            Spacer()

            VStack(spacing: Spacing.sm) {
                if step.warnsPermission {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.gsTitle)
                        .foregroundStyle(Color.gsAccent)
                        .padding(.bottom, Spacing.xxs)
                }

                Text(step.title)
                    .font(.gsTitle)
                    .foregroundStyle(Color.gsTextPrimary)
                    .multilineTextAlignment(.center)

                Text(step.body)
                    .font(.gsBody)
                    .foregroundStyle(Color.gsTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .stageSafeAreaHorizontalPadding(minimum: Spacing.xxl)

            Spacer()

            // 하단: 단계 표시 + 다음
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.xs) {
                    ForEach(viewModel.guideSteps) { s in
                        Capsule()
                            .fill(s.id == step.id ? Color.gsAccent : Color.gsSurface)
                            .frame(width: s.id == step.id ? 20 : 6, height: 6)
                    }
                }
                .animation(.snappy, value: viewModel.guideStep)

                Button(viewModel.isLastGuideStep ? "디바이스 찾기" : "다음") {
                    if viewModel.isLastGuideStep {
                        finish()
                    } else {
                        viewModel.advanceGuide()
                    }
                }
                .font(.gsHeadline)
                .foregroundStyle(Color.gsOnAccent)
                .padding(.horizontal, Spacing.xl)
                .frame(minHeight: HitTarget.minimum)
                .background(Capsule().fill(Color.gsAccent))
            }
            .padding(.bottom, max(Spacing.lg, stageSafeArea.bottom))
        }
        .padding(.top, stageSafeArea.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 끝내든 건너뛰든 **"봤음"으로 기록**하고 기기 찾기로 넘어간다 (SPEC §7).
    private func finish() {
        viewModel.finishGuide()
        router.navigate(to: .peerBrowse)
    }
}

/// 화면 9 — 근처 기기 찾기. (SPEC 플로우 3 / ARCHITECTURE §3.8 · ROADMAP 태스크 U7)
///
/// **`ConnectionFlowState`만 보고 그린다.** Multipeer 내부 사정은 뷰모델이 감춘다.
struct PeerBrowseScreen: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject var viewModel: PeerConnectViewModel

    var body: some View {
        VStack(spacing: Spacing.md) {
            HeaderBar(title: "디바이스 연결", onBack: { router.back() }, onConfirm: nil)

            if viewModel.isConnected {
                connectedCard
                    .stageSafeAreaHorizontalPadding(minimum: Spacing.xl)
            }

            if viewModel.isInitiator {
                // 📱 iPhone(연결 주체) — 찾은 기기 목록을 (연결 중에도) 보여준다.
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(viewModel.isConnected ? "다른 근처 디바이스" : "근처 디바이스")
                            .font(.gsCaption)
                            .foregroundStyle(Color.gsTextTertiary)
                        peerList
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .stageSafeAreaHorizontalPadding(minimum: Spacing.xl)
                }
            } else if !viewModel.isConnected {
                // 📲 iPad(보조) — 연결 전엔 대기 안내만. 연결되면 위 카드로 충분.
                Spacer()
                waitingView
                Spacer()
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { viewModel.startBrowsing() }
        .onDisappear { if !viewModel.isConnected { viewModel.stop() } }
        // 연결되면 "연결됨"을 잠깐 보여준 뒤 원래 연주 화면으로 돌아간다. (다시 오면 위 카드로 상태 확인)
        .onChange(of: viewModel.isConnected) { _, connected in
            guard connected else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard router.currentRoute == .peerBrowse else { return }
                router.returnHome()
            }
        }
    }

    /// 연결된 상대 + 역할 + **연결 끊기**(iPhone 주체). 지금 어떤 기기와 어떻게 연결됐는지 여기서 본다.
    private var connectedCard: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.gsAccent)
                Text("\(viewModel.connectedPeerName ?? "상대")와 연결됨")
                    .font(.gsHeadline)
                    .foregroundStyle(Color.gsTextPrimary)
            }

            Text(roleDescription)
                .font(.gsCaption)
                .foregroundStyle(Color.gsTextSecondary)
                .multilineTextAlignment(.center)

            if viewModel.isInitiator {
                // 연결 해제는 주체인 iPhone이 한다.
                Button("연결 끊기") { viewModel.disconnect() }
                    .font(.gsSubheadline)
                    .foregroundStyle(Color.gsTextPrimary)
                    .padding(.horizontal, Spacing.lg)
                    .frame(minHeight: HitTarget.minimum)
                    .background(Capsule().fill(Color.gsSurface))
                    .padding(.top, Spacing.xxs)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.gsAccent.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.gsAccent.opacity(0.4), lineWidth: 1))
        )
    }

    /// "나: 코드(왼손) · 상대: 스트로크(오른손)" 식의 역할 안내.
    private var roleDescription: String {
        let mine = viewModel.role.displayName
        let theirs = viewModel.partnerRole.displayName
        return "나: \(mine) · 상대: \(theirs)"
    }

    /// iPad가 연결을 기다릴 때.
    private var waitingView: some View {
        VStack(spacing: Spacing.xs) {
            ProgressView().tint(Color.gsTextSecondary)
            Text("연결을 기다리는 중…")
                .font(.gsBody)
                .foregroundStyle(Color.gsTextSecondary)
            Text("상대 iPhone에서 이 디바이스를 선택하면 연결됩니다")
                .font(.gsCaption)
                .foregroundStyle(Color.gsTextTertiary)
        }
    }

    @ViewBuilder
    private var peerList: some View {
        if viewModel.discoveredPeers.isEmpty {
            HStack(spacing: Spacing.xs) {
                ProgressView().tint(Color.gsTextSecondary)
                Text("근처 디바이스를 찾는 중…")
                    .font(.gsSubheadline)
                    .foregroundStyle(Color.gsTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.sm)
        } else {
            ForEach(viewModel.discoveredPeers, id: \.self) { peer in
                Button {
                    viewModel.invite(peer)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "ipad.and.iphone")
                        Text(peer)
                            .font(.gsBody)
                        Spacer()
                        if peer == viewModel.connectedPeerName {
                            Image(systemName: "checkmark").foregroundStyle(Color.gsAccent)
                        } else if case .inviting(let name) = viewModel.flowState, name == peer {
                            ProgressView().tint(Color.gsTextSecondary)
                        }
                    }
                    .foregroundStyle(Color.gsTextPrimary)
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: HitTarget.minimum)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.gsSurface))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
