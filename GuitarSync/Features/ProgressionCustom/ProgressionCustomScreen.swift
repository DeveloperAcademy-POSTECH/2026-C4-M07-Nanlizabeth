import SwiftUI

/// 화면 7 — 코드진행 커스텀. (SPEC 플로우 2 / ARCHITECTURE §3.6 · ROADMAP 태스크 U6)
///
/// 위: 만들고 있는 진행(타임라인) + 전체 미리듣기. 아래: 카탈로그 코드 팔레트.
/// 코드를 탭하면 진행에 붙고 그 코드가 한 번 울린다. 결정하면 저장된다.
///
/// - 코드는 **반드시 `ChordCatalog.shared`에서** 온다 (뷰모델이 그렇게 짜였다) — 프리셋과 재료 공유.
/// - 미리듣기는 **항상 하나만** 재생된다 (`ProgressionPreviewPlayerProtocol` 계약).
struct ProgressionCustomScreen: View {
    @ObservedObject var viewModel: ProgressionCustomViewModel
    let onBack: () -> Void
    /// 저장 완료를 알린다. 보통 이전 화면(진행 선택)으로 돌아간다.
    let onSaved: () -> Void

    private let paletteColumns = Array(
        repeating: GridItem(.flexible(), spacing: Spacing.xs),
        count: 6
    )

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(
                title: "코드 진행 만들기",
                onBack: onBack,
                onConfirm: confirmAction
            )

            timeline
            palette
        }
        .onDisappear { viewModel.stopPreview() }
    }

    /// 저장할 게 있을 때만 확정 버튼을 보인다.
    private var confirmAction: (() -> Void)? {
        guard viewModel.canSave else { return nil }
        return {
            viewModel.save()
            onSaved()
        }
    }

    // MARK: - 타임라인 (만들고 있는 진행)

    private var timeline: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("내 진행")
                    .font(.gsHeadline)
                    .foregroundStyle(Color.gsTextPrimary)
                Spacer()
                previewButton
            }

            if viewModel.items.isEmpty {
                Text("아래에서 코드를 골라 진행을 만들어요")
                    .font(.gsSubheadline)
                    .foregroundStyle(Color.gsTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(viewModel.items) { item in
                            TimelineChip(
                                item: item,
                                onRemove: { viewModel.removeItem(item.id) },
                                onBarChange: { viewModel.changeBars(of: item.id, by: $0) }
                            )
                        }
                    }
                    .frame(minHeight: 72)
                }
            }
        }
        .stageSafeAreaHorizontalPadding(minimum: Spacing.xl)
        .padding(.top, Spacing.sm)
    }

    private var previewButton: some View {
        Button {
            viewModel.isPreviewing ? viewModel.stopPreview() : viewModel.previewAll()
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: viewModel.isPreviewing ? "stop.fill" : "play.fill")
                Text(viewModel.isPreviewing ? "정지" : "전체 듣기")
            }
            .font(.gsSubheadline)
            .foregroundStyle(viewModel.canSave ? Color.gsAccent : Color.gsTextTertiary)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSave)
        .accessibilityLabel(viewModel.isPreviewing ? "미리듣기 정지" : "전체 미리듣기")
    }

    // MARK: - 코드 팔레트 (카탈로그)

    private var palette: some View {
        ScrollView {
            LazyVGrid(columns: paletteColumns, spacing: Spacing.xs) {
                ForEach(viewModel.catalogChords) { chord in
                    Button {
                        viewModel.addChord(chord)
                    } label: {
                        Text(chord.name)
                            .font(.gsHeadline)
                            .foregroundStyle(Color.gsTextPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .fill(Color.gsSurface)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(chord.name) 코드 추가")
                }
            }
            .stageSafeAreaHorizontalPadding(minimum: Spacing.xl)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
    }
}

/// 타임라인의 코드 한 칸. X로 삭제, ±로 마디 수 조절.
private struct TimelineChip: View {
    let item: ProgressionItem
    let onRemove: () -> Void
    let onBarChange: (Int) -> Void

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: Spacing.xxs) {
                Text(item.chord.name)
                    .font(.gsHeadline)
                    .foregroundStyle(Color.gsOnAccent)
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.gsCaption)
                        .foregroundStyle(Color.gsOnAccent.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.chord.name) 삭제")
            }

            HStack(spacing: Spacing.xxs) {
                stepButton("minus", enabled: item.barCount > 1) { onBarChange(-1) }
                Text("\(item.barCount)마디")
                    .font(.gsCaption)
                    .foregroundStyle(Color.gsOnAccent.opacity(0.8))
                stepButton("plus", enabled: true) { onBarChange(1) }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(RoundedRectangle(cornerRadius: Radius.md).fill(Color.gsAccent))
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.gsCaption)
                .foregroundStyle(Color.gsOnAccent.opacity(enabled ? 0.9 : 0.3))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

#Preview("코드진행 커스텀") {
    PortraitLockedLandscapeStage {
        ProgressionCustomScreen(
            viewModel: ProgressionCustomViewModel(library: MockChordProgressionLibrary()),
            onBack: {},
            onSaved: {}
        )
    }
}
