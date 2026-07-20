import SwiftUI

struct BPMPopover: View {
    @Binding var bpm: Double

    var body: some View {
        HStack(spacing: 8) {
            Slider(value: $bpm, in: 40...240)
                .tint(Color.white.opacity(0.88))
                .frame(width: 215)

            Text("\(Int(bpm.rounded()))")
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(width: 300, height: 34)
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
}
