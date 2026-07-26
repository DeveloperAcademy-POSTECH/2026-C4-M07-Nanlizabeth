import SwiftUI

enum OnboardingStartPath {
    case iPhone
    case iPadConnection
}

/// 화면 1 — 첫 실행 온보딩 (3장). (Figma 568-8814 · 568-38977 · 568-38981)
///
/// 세 장의 안내(음량 → 방해금지 → 시작 방식)를 넘겨 보고, 마지막에 사용할 흐름을 고른다.
/// 각 장은 Figma export 이미지를 통째 배경으로 쓴다(상단 페이지 점·일러스트·문구 포함).
/// 아이폰 단독 연주와 아이패드 연결은 서로 다른 화면과 튜토리얼로 이어진다.
///
/// - Note: 방해 금지 모드는 공개 API로 직접 토글할 수 없어 제어 센터 조작을 안내한다.
struct OnboardingScreen: View {
    @State private var page = 0
    @State private var showsDoNotDisturbHelp = false
    @StateObject private var guitarLoop = OnboardingGuitarLoopPlayer()

    private let stage = LayoutTokens.phoneStage
    let onStart: (OnboardingStartPath) -> Void

    init(onStart: @escaping (OnboardingStartPath) -> Void = { _ in }) {
        self.onStart = onStart
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $page) {
                ZStack {
                    pageImage("OnboardingPage1")
                    nextButton {
                        move(to: 1)
                    }
                    .position(x: stage.width / 2, y: 346)
                }
                .tag(0)

                ZStack {
                    Color.gsStageBackground
                    focusModeIllustration
                    focusModeMessage
                    secondPageButtons
                }
                .frame(width: stage.width, height: stage.height)
                .tag(1)
                ZStack {
                    pageImage("OnboardingPage3")
                    startPathButtons
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // 원본 이미지에 포함된 인디케이터를 가리고, 페이지와 함께 움직이지 않는
            // 고정 인디케이터를 같은 자리에 별도 레이어로 표시한다.
            Color.gsStageBackground
                .frame(height: 55)
                .allowsHitTesting(false)

            pageIndicator
                .padding(.top, 26)
        }
        .frame(width: stage.width, height: stage.height)
        .ignoresSafeArea()
        .onAppear { updateGuitarLoop(for: page) }
        .onChange(of: page) { _, newPage in
            updateGuitarLoop(for: newPage)
        }
        .onDisappear { guitarLoop.stop() }
        .alert("집중 모드 켜기", isPresented: $showsDoNotDisturbHelp) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("앱이 집중 모드를 직접 켤 수 없어요. 화면 오른쪽 위에서 제어 센터를 내린 뒤 ‘집중 모드’에서 ‘방해 금지 모드’를 탭해주세요.")
        }
    }

    private var focusModeMessage: some View {
        Text("원활한 연주를 위해 집중 모드 활성화를 권장해요.")
            .font(.gsBody)
            .foregroundStyle(Color.gsTextPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 650)
            .frame(minHeight: 52)
        .position(x: stage.width / 2, y: 250)
    }

    private var focusModeIllustration: some View {
        Image(systemName: "bell.slash")
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 86, weight: .thin))
            .foregroundStyle(Color.gsTextPrimary)
            .frame(width: 150, height: 112)
            .position(x: stage.width / 2, y: 162)
            .accessibilityHidden(true)
    }

    private var secondPageButtons: some View {
        HStack(spacing: 14) {
            Button {
                showsDoNotDisturbHelp = true
            } label: {
                Label("집중 모드", systemImage: "moon.fill")
                    .font(.gsHeadline)
                    .foregroundStyle(Color.gsTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 224, height: 50)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityHint("제어 센터에서 집중 모드를 켜는 방법을 표시합니다.")

            nextButton {
                move(to: 2)
            }
        }
        .position(x: stage.width / 2, y: 346)
    }

    private func nextButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text("다음")
                Image(systemName: "arrow.right")
            }
            .font(.gsHeadline)
            .foregroundStyle(Color.gsOnAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: 150, height: 50)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(Capsule().fill(Color.gsAccent))
        .glassEffect(.clear.interactive(), in: .capsule)
    }

    private func move(to page: Int) {
        withAnimation(.easeInOut(duration: 0.24)) {
            self.page = page
        }
    }

    private var startPathButtons: some View {
        ZStack {
            // 원본 에셋에 포함된 Start 버튼을 같은 배경색으로 가린다.
            Color.gsStageBackground
                .frame(width: 610, height: 70)

            HStack(spacing: 14) {
                startButton(
                    title: "아이폰으로 시작하기",
                    systemImage: "iphone",
                    isPrimary: true
                ) {
                    onStart(.iPhone)
                }

                startButton(
                    title: "아이패드 연결하기",
                    systemImage: "ipad",
                    isPrimary: false
                ) {
                    onStart(.iPadConnection)
                }
            }
        }
        .position(x: stage.width / 2, y: 346)
    }

    private func startButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.gsHeadline)
                .foregroundStyle(isPrimary ? Color.gsOnAccent : Color.gsTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(width: 258, height: 50)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            if isPrimary {
                Capsule().fill(Color.gsAccent)
            }
        }
        .glassEffect(isPrimary ? .clear.interactive() : .regular.interactive(), in: .capsule)
    }

    private func updateGuitarLoop(for page: Int) {
        if page == 0 {
            guitarLoop.play()
        } else {
            guitarLoop.stop()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        index == page
                            ? Color.gsTextPrimary
                            : Color.gsTextPrimary.opacity(0.32)
                    )
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func pageImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: stage.width, height: stage.height)
            .clipped()
    }
}

#Preview("온보딩") {
    PortraitLockedLandscapeStage {
        OnboardingScreen()
    }
}
