import SwiftUI

/// 코드 전환 드릴 화면. (docs/PLAN-chord-drill §4-5)
///
/// **`NeckScreen`을 그대로 품고**(지판·짚은 점·줄 떨림 재사용) 위에 얇은 HUD만 얹는다 —
/// 목표 코드, 진행 표시, 정답 순간 플래시. 짚기 로직·소리 게이트는 `ChordDrillController`가 맡는다.
///
/// - Note: **iPhone 전용 화면**이다. iPad는 왼손을 맡지 않으므로 `AppRoute.isAvailable(on:)`에서 제외된다.
struct ChordDrillScreen: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var controller = ChordDrillController()

    /// 정답 순간 잠깐 켜지는 안내.
    @State private var flashOn = false

    var body: some View {
        ZStack(alignment: .top) {
            NeckScreen(viewModel: controller.neck)
                .ignoresSafeArea()

            hud
        }
        .onAppear {
            controller.start()
            // 화면에 들어오면 자동 주법이 바로 돈다 (모드 A와 동일). 정답일 때만 소리가 난다.
            controller.play(pattern: StrumPatternLibrary().presets.first ?? .fallback, bpm: 80)
        }
        .onDisappear { controller.end() }
        .onChange(of: controller.correctFlash) { _, _ in showFlash() }
    }

    // MARK: - HUD

    private var hud: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                backButton
                Spacer()
                targetLabel
                Spacer()
                progressDots
            }
            flashLabel
        }
        .padding(.top, 14)
        .padding(.horizontal, 16)
    }

    private var backButton: some View {
        Button { router.back() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.gsTextPrimary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.gsSurface.opacity(0.7)))
        }
    }

    private var targetLabel: some View {
        VStack(spacing: 2) {
            Text("이 코드를 짚어보세요")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.gsTextSecondary)
            Text(controller.currentChord.name)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.gsAccent)
                .contentTransition(.numericText())
                .animation(.snappy, value: controller.currentChord)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.gsStageBackground.opacity(0.55)))
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<controller.total, id: \.self) { i in
                Circle()
                    .fill(i == controller.position ? Color.gsAccent : Color.gsHardware)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(minWidth: 40, alignment: .trailing)
    }

    private var flashLabel: some View {
        Text("좋아요! 다음 코드로")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.gsOnAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.gsAccent))
            .opacity(flashOn ? 1 : 0)
            .scaleEffect(flashOn ? 1 : 0.9)
    }

    private func showFlash() {
        withAnimation(.easeOut(duration: 0.15)) { flashOn = true }
        Task {
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.easeIn(duration: 0.2)) { flashOn = false }
        }
    }
}

#Preview("코드 드릴") {
    PortraitLockedLandscapeStage {
        ChordDrillScreen()
            .environmentObject(AppRouter(deviceType: .iPhone))
    }
}
