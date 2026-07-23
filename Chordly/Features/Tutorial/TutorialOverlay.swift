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
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                dialog
                    .frame(maxWidth: 500, alignment: .leading)
                    .stageSafeAreaHorizontalPadding(minimum: 18)
                    .padding(.bottom, max(35, stageSafeArea.bottom))
            }
        }
        .animation(.easeOut(duration: 0.18), value: tutorial.stepIndex)
        .animation(.easeOut(duration: 0.3), value: tutorial.phase)
        .animation(.easeOut(duration: 0.2), value: tutorial.lastActionDone)
    }

    private var dialog: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(headerText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.gsAccent)
                Spacer()
                if showsSkip {
                    Button("이 단계 건너뛰기") { tutorial.skip() }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .buttonStyle(.plain)
                }
            }
            HStack(alignment: .center, spacing: 12) {
                Text(bodyText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                trailingButton
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
        tutorial.isCelebrating ? "Tutorial Complete" : "\(tutorial.displayStepNumber) / \(tutorial.displayTotalSteps)"
    }

    private var bodyText: String {
        tutorial.isCelebrating
            ? "이제 Chordly를 마음껏 즐겨보세요!"
            : (tutorial.currentStep?.message ?? "")
    }

    private var showsSkip: Bool {
        tutorial.isRunning && tutorial.currentStep?.showsCompleteButton == false
    }

    @ViewBuilder private var trailingButton: some View {
        if tutorial.isCelebrating {
            limeButton("시작하기", enabled: true) { tutorial.finish() }
        } else if tutorial.currentStep?.showsCompleteButton == true {
            // 줄을 실제로 튕겨야 활성화된다 (동작 검증).
            limeButton("완료", enabled: tutorial.lastActionDone) { tutorial.complete() }
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
