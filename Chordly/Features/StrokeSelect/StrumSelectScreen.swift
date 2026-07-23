import SwiftUI

/// 화면 4 — 스트로크(주법) 선택. (SPEC §6 화면4 / ROADMAP 태스크 U4)
///
/// Figma HI-FI `스트로크 선택 페이지 - 선택안됨 / 선택됨`을 옮긴 것이다.
/// 목록은 `StrumPatternLibrary`에서 오므로 **CT1이 프리셋을 추가하면 저절로 늘어난다.**
///
/// - Note: **커스텀 주법은 없습니다** (2026-07-20 결정). 프리셋 목록만 보여줍니다.
///   사용자가 직접 만드는 건 코드진행뿐입니다.
/// - Note: 이 화면은 **iPhone 전용**입니다. iPad는 항상 직접 긁으므로 자동 주법을 고를 일이 없습니다.
struct StrumSelectScreen: View {
    @Environment(\.landscapeStageSafeAreaInsets) private var stageSafeArea

    @ObservedObject var viewModel: StrumSelectViewModel
    let onBack: () -> Void
    let onConfirm: () -> Void
    var tutorialHighlight: TutorialHighlightTarget? = nil

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(
                title: "스트로크 선택",
                onBack: onBack,
                onConfirm: onConfirm,
                highlightsConfirm: tutorialHighlight == .returnToChord
            )

            if viewModel.showsFilters {
                filterChips
            }

            patternGrid
        }
        .onDisappear { viewModel.stopPreview() }
    }

    /// 박자 필터. 박자가 한 종류뿐이면 아예 안 나온다.
    private var filterChips: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(viewModel.availableFilters, id: \.self) { filter in
                let isOn = filter == viewModel.filter

                Button {
                    viewModel.filter = filter
                } label: {
                    Text(filter.label)
                        .font(.gsSubheadline)
                        .foregroundStyle(isOn ? Color.gsOnAccent : Color.gsTextPrimary)
                        .padding(.horizontal, Spacing.md)
                        .frame(height: 34)
                        .background(Capsule().fill(isOn ? Color.gsAccent : Color.gsSurface))
                        // 칩은 HI-FI대로 34pt로 그리되, **손가락이 닿는 범위는 44pt로** 넓힌다.
                        // (접근성 최소 터치 크기 — ARCHITECTURE §5 / 태스크 H4)
                        .frame(height: HitTarget.minimum)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }

            Spacer()
        }
        .padding(.leading, max(Spacing.xl, stageSafeArea.leading))
        .padding(.trailing, max(Spacing.xl, stageSafeArea.trailing))
    }

    /// 주법 카드 2열 격자.
    private var patternGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(Array(viewModel.patterns.enumerated()), id: \.element.id) { index, pattern in
                    Button {
                        viewModel.select(pattern)
                    } label: {
                        StrumPatternCard(
                            pattern: pattern,
                            isSelected: viewModel.isSelected(pattern)
                        )
                    }
                    .buttonStyle(.plain)
                    .tutorialPulseHighlight(
                        tutorialHighlight == .strumPatternCard && index == 0,
                        cornerRadius: Radius.lg
                    )
                }
            }
            .padding(.leading, max(Spacing.xl, stageSafeArea.leading))
            .padding(.trailing, max(Spacing.xl, stageSafeArea.trailing))
            .padding(.top, Spacing.xs)
            .padding(.bottom, max(Spacing.lg, stageSafeArea.bottom))
        }
    }
}

/// 주법 하나짜리 카드. 고르면 배경이 형광색으로 뒤집힌다.
private struct StrumPatternCard: View {
    let pattern: StrumPattern
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            StrumPatternNotationView(pattern: pattern, isSelected: isSelected)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 68)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(isSelected ? Color.gsAccent : Color.gsSurface)
        )
        // 화면에 보이는 건 악보 기호뿐이라, 읽어줄 이름은 여기서 따로 준다. (태스크 H4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pattern.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("스트로크 선택") {
    PortraitLockedLandscapeStage {
        StrumSelectScreen(
            viewModel: StrumSelectViewModel(),
            onBack: {},
            onConfirm: {}
        )
    }
}
