import SwiftUI

/// 코드 드릴 **노래 선택** 화면. (docs/PLAN-chord-drill 확장)
///
/// 드릴 버튼을 누르면 바로 시작하지 않고, 먼저 여기서 노래를 하나 고른다. 고른 노래의 코드 진행을
/// 순서대로 짚는 연습으로 이어진다. 곡 목록은 `PracticeSongData`(저작권 없는 동요·전통곡).
///
/// U5(코드진행 선택)와 같은 헤더·카드 스타일을 쓴다. 확정 버튼 없이 **탭하면 바로 시작**한다.
struct ChordDrillSongSelectScreen: View {
    let songs: [PracticeSong]
    let onBack: () -> Void
    let onSelect: (PracticeSong) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(title: "노래 선택", onBack: onBack)

            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(songs) { song in
                        Button { onSelect(song) } label: {
                            SongCard(song: song)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .stageSafeAreaHorizontalPadding(minimum: Spacing.xl)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.lg)
            }
        }
    }
}

/// 노래 하나짜리 카드 — 이름 + 난이도 + 코드 흐름(C → G → Am → F).
private struct SongCard: View {
    let song: PracticeSong

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(song.title)
                    .font(.gsHeadline)
                    .foregroundStyle(Color.gsTextPrimary)
                Spacer()
                Text(song.level)
                    .font(.gsCaption)
                    .foregroundStyle(Color.gsOnAccent)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Capsule().fill(Color.gsAccent))
            }

            chordFlow
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.gsSurface)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(song.title), \(song.level), \(song.uniqueChords.map(\.name).joined(separator: " "))")
        .accessibilityAddTraits(.isButton)
    }

    /// 이 노래에 나오는 코드들을 화살표로 이어 보여준다 (중복 제거).
    private var chordFlow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Array(song.uniqueChords.enumerated()), id: \.offset) { index, chord in
                if index > 0 {
                    Image(systemName: "arrow.right")
                        .font(.gsCaption)
                        .foregroundStyle(Color.gsTextTertiary)
                }
                Text(chord.name)
                    .font(.gsSubheadline)
                    .foregroundStyle(Color.gsTextPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(RoundedRectangle(cornerRadius: Radius.sm).fill(Color.black.opacity(0.25)))
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview("노래 선택") {
    PortraitLockedLandscapeStage {
        ChordDrillSongSelectScreen(
            songs: PracticeSongData.songs,
            onBack: {},
            onSelect: { _ in }
        )
    }
}
