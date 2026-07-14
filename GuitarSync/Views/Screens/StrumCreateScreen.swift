import SwiftUI

struct StrumCreateScreen: View {
    let onBack: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(title: "스트로크 생성", onBack: onBack, onConfirm: onConfirm)
            TimelineView()
                .padding(.horizontal, 44)
                .padding(.top, 44)
            Spacer()
        }
    }
}
