import Combine
import Foundation

/// 주법(스트로크)을 선택 전에 짧게 들려주는 미리듣기. (ROADMAP 태스크 U4 미리듣기)
///
/// 진행 미리듣기(`ProgressionPreviewPlayer`)의 스트럼판이다. 코드는 바뀌지 않고 **한 코드(기본 C)로
/// 그 주법의 리듬만** 들려준다 — "이 주법이 어떤 리듬인지"를 확인하는 게 목적이라 코드는 고정한다.
///
/// ## 규칙: 한 번에 하나만 (진행 미리듣기와 동일)
///
/// 새 미리듣기를 시작하면 이전 것은 자동으로 멈춘다.
@MainActor
final class StrumPatternPreviewPlayer: ObservableObject {
    @Published private(set) var isPreviewing = false

    /// 몇 번 반복하고 멈출지. 짧아야 "맛보기"다.
    private let previewLoopCount = 2

    /// 어떤 코드로 들려줄지. 리듬 확인이 목적이라 익숙한 C로 고정.
    let previewChord: GuitarChord

    private let engine: GuitarAudioEngineProtocol?
    private let clock: BeatClockProtocol
    private var clockSubscription: AnyCancellable?

    private var stepsByTick: [Int: [StrumStep]] = [:]
    private var loopLengthInTicks = 0

    init(
        engine: GuitarAudioEngineProtocol?,
        clock: BeatClockProtocol? = nil,
        previewChord: GuitarChord = .c
    ) {
        self.engine = engine
        self.clock = clock ?? BeatClock()
        self.previewChord = previewChord
    }

    func preview(_ pattern: StrumPattern) {
        stopPreview()
        guard !pattern.steps.isEmpty else { return }

        loopLengthInTicks = max(pattern.barCount * pattern.timeSignature.subdivisionsPerBar, 1)
        stepsByTick = Dictionary(grouping: pattern.steps) {
            $0.position.tickIndex(in: pattern.timeSignature)
        }

        engine?.start()
        clockSubscription = clock.beats
            .sink { [weak self] event in self?.handleTick(event) }

        isPreviewing = true
        clock.start(bpm: pattern.recommendedBPM, timeSignature: pattern.timeSignature)
    }

    func stopPreview() {
        clock.stop()
        clockSubscription = nil
        engine?.stopAllStrings()
        isPreviewing = false
    }

    // MARK: - 내부

    private func handleTick(_ event: BeatEvent) {
        // 정해둔 횟수만큼 돌면 끝.
        if event.tickIndex >= loopLengthInTicks * previewLoopCount {
            stopPreview()
            return
        }

        let tickInLoop = event.tickIndex % loopLengthInTicks
        guard let steps = stepsByTick[tickInLoop] else { return }

        let frets = previewChord.fingering.frets
        for step in steps {
            engine?.strum(
                frets: frets,
                direction: step.direction,
                velocity: step.accent.velocity,
                interval: 0.03
            )
        }
    }
}
