import SwiftUI

/// 화면 6 — 코드진행 선택. (SPEC §6 화면6 / ROADMAP 태스크 U5)
///
/// 프리셋 진행 목록에서 하나를 골라 확정한다. **모드 B의 자동 왼손이 이걸로 정해진다.**
/// 마음에 드는 게 없으면 "직접 만들기"로 커스텀 화면(U6)에 간다.
///
/// U4(스트로크 선택)와 짝을 이루는 화면이라 헤더·확정 버튼·선택 반전을 똑같이 쓴다.
struct ProgressionSelectScreen: View {
    @Environment(\.landscapeStageSafeAreaInsets) private var stageSafeArea

    @ObservedObject var viewModel: ProgressionSelectViewModel
    let onBack: () -> Void
    let onConfirm: () -> Void
    /// "직접 만들기" → 커스텀 화면(U6)으로.
    var onCreateCustom: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(title: "코드 진행 선택", onBack: onBack, onConfirm: onConfirm)

            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(viewModel.progressions) { progression in
                        Button {
                            viewModel.select(progression)
                        } label: {
                            ProgressionCard(
                                progression: progression,
                                isSelected: viewModel.isSelected(progression)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if let onCreateCustom {
                        CreateCustomRow(action: onCreateCustom)
                            .padding(.top, Spacing.xs)
                    }
                }
                .padding(.leading, max(Spacing.xl, stageSafeArea.leading))
                .padding(.trailing, max(Spacing.xl, stageSafeArea.trailing))
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.lg)
            }
        }
        .onDisappear { viewModel.stopPreview() }
    }
}

/// 진행 하나짜리 카드 — 이름 + 코드 흐름(C → G → Am → F).
private struct ProgressionCard: View {
    let progression: ChordProgression
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(progression.name)
                    .font(.gsHeadline)
                    .foregroundStyle(isSelected ? Color.gsOnAccent : Color.gsTextPrimary)
                Spacer()
                if progression.source == .custom {
                    Text("내가 만든")
                        .font(.gsCaption)
                        .foregroundStyle(isSelected ? Color.gsOnAccent.opacity(0.6) : Color.gsTextSecondary)
                }
            }

            chordFlow
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(isSelected ? Color.gsAccent : Color.gsSurface)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(progression.name), \(chordNames.joined(separator: " "))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// 코드 이름들을 화살표로 이어 보여준다. 각 코드가 몇 마디인지는 칩 아래 작은 글씨로.
    private var chordFlow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Array(progression.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Image(systemName: "arrow.right")
                        .font(.gsCaption)
                        .foregroundStyle(isSelected ? Color.gsOnAccent.opacity(0.5) : Color.gsTextTertiary)
                }
                chordChip(item)
            }
            Spacer(minLength: 0)
        }
    }

    private func chordChip(_ item: ProgressionItem) -> some View {
        VStack(spacing: 1) {
            Text(item.chord.name)
                .font(.gsSubheadline)
                .foregroundStyle(isSelected ? Color.gsOnAccent : Color.gsTextPrimary)
            if item.barCount > 1 {
                Text("\(item.barCount)마디")
                    .font(.gsCaption)
                    .foregroundStyle(isSelected ? Color.gsOnAccent.opacity(0.6) : Color.gsTextSecondary)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(isSelected ? Color.gsOnAccent.opacity(0.12) : Color.black.opacity(0.25))
        )
    }

    private var chordNames: [String] { progression.items.map(\.chord.name) }
}

/// "직접 만들기" 진입 줄.
private struct CreateCustomRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus.circle")
                Text("직접 만들기")
            }
            .font(.gsHeadline)
            .foregroundStyle(Color.gsAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Color.gsAccent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("코드진행 선택") {
    PortraitLockedLandscapeStage {
        ProgressionSelectScreen(
            viewModel: ProgressionSelectViewModel(library: MockChordProgressionLibrary()),
            onBack: {},
            onConfirm: {},
            onCreateCustom: {}
        )
    }
}
