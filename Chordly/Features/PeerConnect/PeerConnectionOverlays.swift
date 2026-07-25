import Combine
import SwiftUI
import UIKit

private struct DeviceNamePromptHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct DeviceNamePrompt: View {
    let initialName: String
    let onSave: (String) -> Void

    @Environment(\.stageMetrics) private var stageMetrics
    @State private var name = ""
    @State private var keyboardFrame = CGRect.null
    @State private var promptHeight: CGFloat = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { stageProxy in
            ZStack {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)

                VStack(spacing: 16) {
                    Text("디바이스 이름을 지어주세요")
                        .font(.gsHeading)
                        .bold()
                        .foregroundStyle(Color.gsTextPrimary)

                    Text("이 이름은 다른 디바이스의 연결 목록에 표시됩니다.")
                        .font(.gsSubheadline)
                        .foregroundStyle(Color.gsTextSecondary)

                    TextField("예: 민서의 iPad", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.gsBody)
                        .foregroundStyle(Color.gsTextPrimary)
                        .padding(.horizontal, 16)
                        .frame(width: 320, height: 48)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit(save)

                    Button("이 이름 사용하기", action: save)
                        .font(.gsHeadline)
                        .foregroundStyle(Color.gsOnAccent)
                        .padding(.horizontal, 28)
                        .frame(height: 46)
                        .background(Capsule().fill(Color.gsAccent))
                        .disabled(trimmedName.isEmpty)
                        .opacity(trimmedName.isEmpty ? 0.4 : 1)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .rotationEffect(
                    .degrees(DeviceInfoProvider.currentDeviceType == .iPad ? 0 : 90)
                )
                .background {
                    GeometryReader { promptProxy in
                        Color.clear.preference(
                            key: DeviceNamePromptHeightKey.self,
                            value: promptProxy.size.height
                        )
                    }
                }
                .offset(y: -keyboardAvoidanceOffset(in: stageProxy.frame(in: .global)))
            }
            .onPreferenceChange(DeviceNamePromptHeightKey.self) { promptHeight = $0 }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            name = initialName
            isFocused = true
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification
            )
        ) { notification in
            updateKeyboardFrame(from: notification)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification
            )
        ) { notification in
            animateKeyboardChange(from: notification) {
                keyboardFrame = .null
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        isFocused = false
        onSave(trimmedName)
    }

    private func keyboardAvoidanceOffset(in stageFrame: CGRect) -> CGFloat {
        guard DeviceInfoProvider.currentDeviceType == .iPad,
              promptHeight > 0,
              !keyboardFrame.isNull else {
            return 0
        }

        let scale = max(stageMetrics.scale, 0.01)
        let margin = 12 * scale
        let promptBottom = stageFrame.midY + promptHeight * scale / 2
        let requiredPhysicalOffset = max(
            0,
            promptBottom + margin - keyboardFrame.minY
        )
        let maximumPhysicalOffset = max(
            0,
            stageFrame.midY - stageFrame.minY - promptHeight * scale / 2 - margin
        )

        return min(requiredPhysicalOffset, maximumPhysicalOffset) / scale
    }

    private func updateKeyboardFrame(from notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
            as? CGRect else {
            return
        }

        animateKeyboardChange(from: notification) {
            keyboardFrame = frame
        }
    }

    private func animateKeyboardChange(
        from notification: Notification,
        changes: @escaping () -> Void
    ) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey]
            as? Double ?? 0.25
        withAnimation(.easeOut(duration: duration), changes)
    }
}

struct PeerConnectedPopup: View {
    let peerName: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color.gsAccent)

                Text("연결됐어요!")
                    .font(.gsTitle)
                    .bold()
                    .foregroundStyle(Color.gsTextPrimary)

                Text("\(peerName)와 함께 연주할 수 있어요.")
                    .font(.gsBody)
                    .foregroundStyle(Color.gsTextSecondary)

                Button("확인", action: onDismiss)
                    .font(.gsHeadline)
                    .foregroundStyle(Color.gsOnAccent)
                    .padding(.horizontal, 28)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.gsAccent))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 24)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }
}

struct PeerInvitationPopup: View {
    let peerName: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            VStack(spacing: 12) {
                Image(systemName: "ipad.and.iphone")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color.gsAccent)

                Text("연결 요청")
                    .font(.gsTitle)
                    .bold()
                    .foregroundStyle(Color.gsTextPrimary)

                Text("\(peerName)에서 함께 연주하자고 요청했어요.")
                    .font(.gsBody)
                    .foregroundStyle(Color.gsTextSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button("거절", action: onDecline)
                        .font(.gsHeadline)
                        .foregroundStyle(Color.gsTextPrimary)
                        .frame(width: 96, height: 44)
                        .background(Capsule().fill(Color.black.opacity(0.42)))

                    Button("수락", action: onAccept)
                        .font(.gsHeadline)
                        .foregroundStyle(Color.gsOnAccent)
                        .frame(width: 96, height: 44)
                        .background(Capsule().fill(Color.gsAccent))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 24)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }
}
