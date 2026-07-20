import SwiftUI

/// 주법 하나를 악보 기호로 보여준다. (Figma HI-FI `스트로크 선택 페이지` · 태스크 U4)
///
/// 박마다 **음표 하나**를 그리고 그 아래 **긁는 방향**을 적는다.
///
/// ```
///  ♩     ♫     ♩     ♫
///  ∩    ∩∨     ∩    ∩∨
/// ```
///
/// **기호는 `steps`에서 계산해서 나온다** — 하드코딩이 아니라서 CT1이 리듬을 넣으면
/// 그림이 저절로 그 리듬을 그린다.
struct StrumPatternNotationView: View {
    let pattern: StrumPattern
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(beats, id: \.beat) { beat in
                VStack(spacing: 2) {
                    Text(beat.glyph)
                        // 악보 기호는 크기가 곧 의미라 다이내믹 타입을 끈다.
                        .font(.gsFixed(25, weight: .semibold))
                        .foregroundStyle(noteColor)

                    Text(beat.directionMarks)
                        .font(.gsSubheadline)
                        .foregroundStyle(markColor)
                }
            }
        }
    }

    /// 선택된 카드는 배경이 형광색이라 글자를 검정으로 뒤집는다.
    private var noteColor: Color {
        isSelected ? Color.gsOnAccent : Color.gsTextPrimary
    }

    private var markColor: Color {
        isSelected ? Color.gsOnAccent.opacity(0.55) : Color.gsTextPrimary.opacity(0.34)
    }

    /// 첫 마디를 박 단위로 묶은 것. **목록에서는 한 마디만** 보여준다 — 카드가 좁아서다.
    private var beats: [BeatNotation] {
        let firstBar = pattern.steps.filter { $0.position.bar == 0 }
        let grouped = Dictionary(grouping: firstBar, by: \.position.beat)

        return (0..<max(pattern.timeSignature.beatsPerBar, 1)).map { beat in
            BeatNotation(
                beat: beat,
                steps: (grouped[beat] ?? []).sorted { $0.position < $1.position }
            )
        }
    }
}

/// 한 박에 들어간 스텝들 → 음표 기호와 방향 표시.
private struct BeatNotation {
    let beat: Int
    let steps: [StrumStep]

    /// 한 박을 몇 번 긁는지로 음표를 고른다. **쉬는 박은 가운뎃점**으로 자리만 잡는다.
    var glyph: String {
        switch steps.count {
        case 0: return "·"
        case 1: return "♩"
        case 2: return "♫"
        default: return "♬"
        }
    }

    /// `∩` = 아래로 훑기(저음→고음) · `∨` = 위로. (ARCHITECTURE §5 방향 규약)
    var directionMarks: String {
        steps.map { $0.direction == .down ? "∩" : "∨" }.joined()
    }
}

#Preview("주법 기호") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        ForEach(StrumPresetData.patterns) { pattern in
            StrumPatternNotationView(pattern: pattern)
        }
    }
    .padding(Spacing.xl)
    .background(Color.gsStageBackground)
}
