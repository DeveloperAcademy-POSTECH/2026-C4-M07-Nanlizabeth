import SwiftUI

/// 화면 8 — 연결 가이드. (SPEC 플로우 3 / ARCHITECTURE §3.8 · ROADMAP 태스크 U7)
///
/// - Important: ⚠️ **HI-FI 디자인이 없어 토큰만으로 만든 초안입니다.**
///   구조를 일부러 단순하게 뒀으니, 디자인이 나오면 이 파일과 `PeerGuideStep.all(...)`의
///   문구만 갈아끼우면 됩니다.
struct PeerGuideScreen: View {
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
            .padding(.horizontal, Spacing.lg)

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
            .padding(.horizontal, Spacing.xxl)

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

                Button(viewModel.isLastGuideStep ? "기기 찾기" : "다음") {
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
            .padding(.bottom, Spacing.lg)
        }
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
        VStack(spacing: 0) {
            HeaderBar(title: "기기 찾기", onBack: { router.back() }, onConfirm: nil)

            Spacer()

            switch viewModel.flowState {
            case .connected(let peerName):
                statusView(
                    icon: "checkmark.circle.fill",
                    tint: Color.gsAccent,
                    title: "\(peerName)와 연결됐어요",
                    detail: "이제 \(viewModel.partnerRole.displayName)은 상대 기기가 맡습니다."
                )

            case .failed(let message):
                statusView(
                    icon: "exclamationmark.circle.fill",
                    tint: Color.gsTextSecondary,
                    title: "연결하지 못했어요",
                    detail: message
                )

            case .disconnected:
                statusView(
                    icon: "wifi.slash",
                    tint: Color.gsTextSecondary,
                    title: "연결이 끊어졌어요",
                    detail: "다시 찾아볼까요?"
                )

            default:
                peerList
            }

            Spacer()

            Button(viewModel.isConnected ? "연결 끊기" : "다시 찾기") {
                if viewModel.isConnected {
                    viewModel.stop()
                } else {
                    viewModel.startBrowsing()
                }
            }
            .font(.gsHeadline)
            .foregroundStyle(Color.gsTextPrimary)
            .padding(.horizontal, Spacing.xl)
            .frame(minHeight: HitTarget.minimum)
            .background(Capsule().fill(Color.gsSurface))
            .padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { viewModel.startBrowsing() }
        .onDisappear { if !viewModel.isConnected { viewModel.stop() } }
        // 연결되면 "연결됐어요"를 잠깐 보여준 뒤 원래 연주 화면으로 자연스럽게 돌아간다.
        .onChange(of: viewModel.isConnected) { _, connected in
            guard connected else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.3))
                // 그새 사용자가 딴 데로 갔으면 끌어오지 않는다.
                guard router.currentRoute == .peerBrowse else { return }
                router.returnHome()
            }
        }
    }

    @ViewBuilder
    private var peerList: some View {
        VStack(spacing: Spacing.sm) {
            if viewModel.discoveredPeers.isEmpty {
                ProgressView()
                    .tint(Color.gsTextSecondary)
                Text("근처 기기를 찾는 중…")
                    .font(.gsBody)
                    .foregroundStyle(Color.gsTextSecondary)
                Text("상대 기기에서도 이 화면을 열어주세요")
                    .font(.gsCaption)
                    .foregroundStyle(Color.gsTextTertiary)
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
                            if case .inviting(let name) = viewModel.flowState, name == peer {
                                ProgressView().tint(Color.gsTextSecondary)
                            }
                        }
                        .foregroundStyle(Color.gsTextPrimary)
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: HitTarget.minimum)
                        .frame(maxWidth: 420)
                        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.gsSurface))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func statusView(icon: String, tint: Color, title: String, detail: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.gsTitle)
                .foregroundStyle(tint)
            Text(title)
                .font(.gsHeading)
                .foregroundStyle(Color.gsTextPrimary)
            Text(detail)
                .font(.gsBody)
                .foregroundStyle(Color.gsTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.xxl)
    }
}
