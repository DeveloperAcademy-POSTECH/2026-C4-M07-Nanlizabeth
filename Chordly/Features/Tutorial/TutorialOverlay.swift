import SwiftUI

/// 튜토리얼 오버레이 — **이미 완성된 화면 위에** 하단 대화창(리퀴드글라스)을 얹는다.
/// 진행 중엔 단계 안내·건너뛰기·(마지막) 완료 버튼, 끝나면 빵빠레 + "시작하기". (Figma 960-2623 · 815-6252)
///
/// 대화창 밖은 터치를 막지 않는다 — 사용자가 실제로 짚고·긁고·이동해야 단계가 넘어가기 때문.
struct TutorialOverlay: View {
    @Environment(\.landscapeStageSafeAreaInsets) private var stageSafeArea
    @ObservedObject var tutorial: TutorialController

    var body: some View {
        ZStack {
            if tutorial.isCelebrating {
                ConfettiView()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            if tutorial.showsSuccessBorder {
                TutorialSuccessBorder()
                    .transition(.opacity)
            }
            if tutorial.showsChordConfetti {
                ConfettiView(count: 34)
                    .frame(width: 430, height: 210)
                    .clipped()
                    .position(x: 520, y: 190)
                    .transition(.opacity)
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                dialogGroup
                    .frame(
                        width: tutorial.keepsBPMKeypadClear ? 370 : 500,
                        alignment: .leading
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: tutorial.keepsBPMKeypadClear ? .leading : .center
                    )
                    .stageSafeAreaHorizontalPadding(minimum: 18)
                    .padding(.bottom, max(35, stageSafeArea.bottom))
            }
        }
        .animation(.easeOut(duration: 0.18), value: tutorial.stepIndex)
        .animation(.easeOut(duration: 0.3), value: tutorial.phase)
        .animation(.easeOut(duration: 0.2), value: tutorial.lastActionDone)
    }

    private var dialogGroup: some View {
        dialog
        .rotationEffect(.degrees(tutorial.rotatesDialogForUpsideDownViewing ? 180 : 0))
    }

    private var dialog: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 18) {
                Text(headerText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.gsAccent)
                tutorialControl
                Spacer(minLength: 0)
            }
            HStack(alignment: .center, spacing: 12) {
                Text(bodyText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                trailingButton
            }
            if tutorial.showsFingerNumberLegend {
                fingerNumberLegend
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.42)))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.14), lineWidth: 1))
        )
    }

    // MARK: 내용

    private var headerText: String {
        if tutorial.isCelebrating { return tutorial.celebrationTitle }
        if tutorial.isReadyToEnjoy { return "Ready" }
        if tutorial.isConnectionTutorial {
            return "디바이스 연결해보기 · \(tutorial.displayStepNumber) / \(tutorial.displayTotalSteps)"
        }
        return "\(tutorial.displayStepNumber) / \(tutorial.displayTotalSteps)"
    }

    private var bodyText: String {
        if tutorial.isCelebrating {
            return tutorial.celebrationMessage
        }
        if tutorial.isReadyToEnjoy {
            return "노래 목록에서 원하는 곡을 골라 마음껏 즐겨보세요!"
        }
        return tutorial.displayMessage
    }

    private var showsSkip: Bool {
        tutorial.isRunning && tutorial.currentStep?.allowsSkip == true
    }

    @ViewBuilder private var tutorialControl: some View {
        // 축하 화면에선 "시작하기"가 끝맺으므로 종료 버튼을 함께 두지 않는다.
        if tutorial.isConnectionTutorial, tutorial.isRunning {
            tutorialControlButton("튜토리얼 종료") {
                tutorial.endConnectionTutorial()
            }
        } else if showsSkip {
            tutorialControlButton("이 단계 건너 뛰기") {
                tutorial.skip()
            }
        }
    }

    private func tutorialControlButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.gsTextPrimary.opacity(0.78))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background {
                    Capsule()
                        .fill(Color.black.opacity(0.48))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var fingerNumberLegend: some View {
        HStack(spacing: 12) {
            Text("손가락 번호")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.gsTextSecondary)

            fingerLegendItem(number: 1, name: "검지")
            fingerLegendItem(number: 2, name: "중지")
            fingerLegendItem(number: 3, name: "약지")
            fingerLegendItem(number: 4, name: "새끼")
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("손가락 번호, 1 검지, 2 중지, 3 약지, 4 새끼")
    }

    private func fingerLegendItem(number: Int, name: String) -> some View {
        HStack(spacing: 4) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.gsOnAccent)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.gsAccent))
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.gsTextPrimary)
        }
    }

    @ViewBuilder private var trailingButton: some View {
        if tutorial.isCelebrating {
            limeButton(tutorial.celebrationButtonTitle, enabled: true) {
                tutorial.continueAfterCelebration()
            }
        } else if tutorial.isReadyToEnjoy {
            limeButton("즐기기", enabled: true) { tutorial.finish() }
        } else if let title = tutorial.currentStep?.actionButtonTitle {
            limeButton(title, enabled: tutorial.lastActionDone) {
                tutorial.confirmCurrentStep()
            }
        }
    }

    private func limeButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.gsOnAccent)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.gsAccent.opacity(enabled ? 1 : 0.35)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct TutorialSuccessBorder: View {
    @State private var isBright = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 48)
                .stroke(Color.gsAccent.opacity(isBright ? 1 : 0.30), lineWidth: isBright ? 5 : 2)
                .shadow(color: Color.gsAccent.opacity(isBright ? 0.95 : 0.25), radius: isBright ? 14 : 4)
                .padding(14)

            RoundedRectangle(cornerRadius: 43)
                .stroke(Color.white.opacity(isBright ? 0.68 : 0.12), lineWidth: 1.5)
                .padding(19)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                isBright = true
            }
        }
    }
}

// MARK: - 빵빠레

/// 가벼운 색종이 애니메이션. 위에서 색색의 조각이 흔들리며 계속 떨어진다.
struct ConfettiView: View {
    private struct Piece {
        let x0: CGFloat, speed: CGFloat, sway: CGFloat, phase: CGFloat
        let color: Color, w: CGFloat, h: CGFloat, spin: CGFloat
    }

    private let pieces: [Piece]
    private let start = Date()

    init(count: Int = 110) {
        let colors: [Color] = [
            Color(red: 0.95, green: 0.26, blue: 0.21), Color(red: 0.98, green: 0.55, blue: 0.13),
            Color(red: 0.96, green: 0.85, blue: 0.24), Color(red: 0.30, green: 0.76, blue: 0.44),
            Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.61, green: 0.35, blue: 0.85),
            Color(red: 0.95, green: 0.45, blue: 0.70),
        ]
        pieces = (0..<count).map { _ in
            Piece(
                x0: .random(in: 0...1), speed: .random(in: 90...210), sway: .random(in: 10...42),
                phase: .random(in: 0...6.28), color: colors.randomElement()!,
                w: .random(in: 6...12), h: .random(in: 9...16), spin: .random(in: -4...4)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = CGFloat(timeline.date.timeIntervalSince(start))
                let travel = size.height + 60
                for piece in pieces {
                    let y = (-30 + t * piece.speed).truncatingRemainder(dividingBy: travel)
                    let x = piece.x0 * size.width + sin(t * 1.5 + piece.phase) * piece.sway
                    let rect = CGRect(x: -piece.w / 2, y: -piece.h / 2, width: piece.w, height: piece.h)
                    let transform = CGAffineTransform(rotationAngle: t * piece.spin + piece.phase)
                        .concatenating(CGAffineTransform(translationX: x, y: y))
                    context.fill(Path(rect).applying(transform), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
