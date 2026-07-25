import SwiftUI

struct BPMPopover: View {
    @Binding var bpm: Double
    var arrowOffsetX: CGFloat = 0
    var highlightsNumber = false
    var onCommit: (Double) -> Void = { _ in }
    var onDismiss: () -> Void = {}

    /// 숫자를 탭하면 **앱 내부 숫자패드**로 직접 입력하는 모드가 된다.
    @State private var isEditing = false
    @State private var editText = ""

    /// 현실적으로 쓰이는 BPM 범위. (초보 기타·동요/포크 기준 리서치)
    /// 초보 코드 전환 연습은 50~70, 대중가요는 대부분 80~140에 몰려 있고 빠른 곡도 ~168.
    /// 그래서 느린 연습(50)~빠른 곡(180)으로 좁혔다 — 기존 40~240은 스트러밍엔 비현실적.
    private let range: ClosedRange<Double> = 50...180

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                // 슬라이더는 **10단위**로만 움직인다.
                Slider(value: $bpm, in: range, step: 10)
                    .tint(Color.white.opacity(0.88))
                    .frame(width: 270)

                number
            }

            // ⚠️ 시스템 키보드는 화면 회전(iPhone 세로고정+콘텐츠 -90°)과 어긋나 세로로 뜬다.
            // 그래서 **스테이지 안에서 함께 회전하는 커스텀 숫자패드**를 쓴다 (가로로 바르게 보임).
            if isEditing {
                BPMKeypad(
                    onDigit: appendDigit,
                    onDelete: deleteLast,
                    onDone: commitAndDismiss
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, isEditing ? 12 : 0)
        .frame(width: 365, height: isEditing ? nil : 44)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(Color(red: 0.30, green: 0.34, blue: 0.42).opacity(0.95))
        )
        .overlay(alignment: .top) {
            Triangle()
                .fill(Color(red: 0.30, green: 0.34, blue: 0.42).opacity(0.95))
                .frame(width: 24, height: 14)
                .offset(x: arrowOffsetX, y: -12)
        }
        .animation(.easeOut(duration: 0.16), value: isEditing)
    }

    /// BPM 숫자. 탭하면 편집 모드로. 편집 중엔 형광색으로 강조.
    private var number: some View {
        Text(displayText)
            .monospacedDigit()
            .foregroundStyle(isEditing ? Color.gsAccent : .white)
            .frame(width: 48, alignment: .trailing)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill((isEditing ? Color.gsAccent : Color.white).opacity(0.5))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
            .tutorialPulseHighlight(highlightsNumber, cornerRadius: 8)
            .onTapGesture {
                if isEditing {
                    commit()
                } else {
                    editText = ""
                    isEditing = true
                }
            }
    }

    /// 편집 중이면 입력값(비어 있으면 현재값 힌트), 아니면 현재 BPM.
    private var displayText: String {
        if isEditing {
            return editText.isEmpty ? "\(Int(bpm.rounded()))" : editText
        }
        return "\(Int(bpm.rounded()))"
    }

    // MARK: - 입력

    private func appendDigit(_ digit: Int) {
        guard editText.count < 3 else { return }   // BPM은 세 자리면 충분
        editText += "\(digit)"
    }

    private func deleteLast() {
        editText = String(editText.dropLast())
    }

    /// 입력한 값을 범위(50~180) 안으로 맞춰 반영하고 편집을 끝낸다.
    private func commit() {
        if let value = Int(editText) {
            bpm = min(max(Double(value), range.lowerBound), range.upperBound)
        }
        editText = ""
        isEditing = false
    }

    /// 숫자패드의 완료는 입력 확정과 동시에 BPM 팝오버 전체를 닫는다.
    private func commitAndDismiss() {
        commit()
        onCommit(bpm)
        onDismiss()
    }
}

/// 스테이지 안에서 함께 회전하는 커스텀 숫자패드. (시스템 키보드가 세로로 뜨는 문제 회피)
private struct BPMKeypad: View {
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    private let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { digit in
                        key(text: "\(digit)") { onDigit(digit) }
                    }
                }
            }
            HStack(spacing: 6) {
                key(systemName: "delete.left", action: onDelete)
                key(text: "0") { onDigit(0) }
                key(text: "완료", tint: Color.gsAccent, foreground: Color.gsOnAccent, action: onDone)
            }
        }
    }

    private func key(
        text: String,
        tint: Color = Color.white.opacity(0.14),
        foreground: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 54, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(tint))
        }
        .buttonStyle(.plain)
    }

    private func key(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 38)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }
}
