import SwiftUI

struct BPMPopover: View {
    @Binding var bpm: Double

    /// 숫자를 탭하면 키패드로 직접 입력하는 모드로 바뀐다.
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var fieldFocused: Bool

    private let range: ClosedRange<Double> = 40...240

    var body: some View {
        HStack(spacing: 8) {
            // 슬라이더는 **10단위**로만 움직인다.
            Slider(value: $bpm, in: range, step: 10)
                .tint(Color.white.opacity(0.88))
                .frame(width: 270)

            number
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(width: 365, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(Color(red: 0.30, green: 0.34, blue: 0.42).opacity(0.95))
        )
        .overlay(alignment: .top) {
            Triangle()
                .fill(Color(red: 0.30, green: 0.34, blue: 0.42).opacity(0.95))
                .frame(width: 24, height: 14)
                .offset(y: -12)
        }
    }

    @ViewBuilder
    private var number: some View {
        if isEditing {
            // 숫자패드로 직접 입력. 키패드엔 완료 키가 없어 상단 액세서리에 "완료"를 둔다.
            TextField("", text: $editText)
                .keyboardType(.numberPad)
                .focused($fieldFocused)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(width: 48, alignment: .trailing)
                .onChange(of: fieldFocused) { _, focused in
                    if !focused { commit() }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("완료") { commit() }
                    }
                }
        } else {
            // 탭하면 키패드 입력으로. 밑줄로 "누를 수 있음"을 살짝 알린다.
            Text("\(Int(bpm.rounded()))")
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(height: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editText = String(Int(bpm.rounded()))
                    isEditing = true
                    fieldFocused = true
                }
        }
    }

    /// 입력한 값을 범위(40~240) 안으로 맞춰 반영하고 편집을 끝낸다.
    private func commit() {
        guard isEditing else { return }
        if let value = Int(editText) {
            bpm = min(max(Double(value), range.lowerBound), range.upperBound)
        }
        isEditing = false
        fieldFocused = false
    }
}
