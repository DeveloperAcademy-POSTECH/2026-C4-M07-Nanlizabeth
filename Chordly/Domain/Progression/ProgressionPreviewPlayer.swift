import Combine
import Foundation

/// 진행/코드를 선택 전에 짧게 들려주는 미리듣기. **모드가 아니라 "맛보기".** (ROADMAP 태스크 L4)
///
/// ## 왜 자체 완결 루프인가
///
/// 미리듣기는 **양손이 다 자동**이다 — 코드도 저절로 바뀌고 긁기도 저절로 된다. 모드 B(L3+수동 긁기)나
/// 모드 A(수동 짚기+L2)와 달리 사람 입력이 없어서, 코디네이터·소스를 끌어오는 것보다 클럭에
/// 기본 주법을 직접 얹는 게 단순하고 정확하다.
///
/// ## 규칙: 한 번에 하나만 (계약)
///
/// 새 미리듣기를 시작하면 이전 것은 자동으로 멈춘다. `previewChord`↔`preview`가 서로를 끊는다.
@MainActor
final class ProgressionPreviewPlayer: ProgressionPreviewPlayerProtocol, ObservableObject {
    @Published private(set) var isPreviewing = false

    /// 미리듣기가 반복하는 횟수. 짧아야 "맛보기"다.
    private let previewLoopCount = 2

    private let engine: GuitarAudioEngineProtocol?
    private let clock: BeatClockProtocol
    private var clockSubscription: AnyCancellable?

    /// 기본 주법 — 매 박 정박 다운. 미리듣기는 리듬 감상이 목적이 아니라 코드 진행 확인이 목적이라
    /// 담백한 4비트를 쓴다.
    private let previewPattern = StrumPattern(
        name: "미리듣기 기본",
        steps: (0..<4).map { StrumStep(beat: $0, .down, $0 == 0 ? .strong : .medium) },
        recommendedBPM: 90
    )
    private var stepTicks: Set<Int> = []
    private var subdivisionsPerBar = TimeSignature.fourFour.subdivisionsPerBar

    private var progression: ChordProgression?

    init(engine: GuitarAudioEngineProtocol?, clock: BeatClockProtocol? = nil) {
        self.engine = engine
        self.clock = clock ?? BeatClock()
        self.stepTicks = Set(previewPattern.steps.map { $0.position.tickIndex(in: .fourFour) })
    }

    func preview(_ progression: ChordProgression) {
        stopPreview()
        guard progression.totalBars > 0 else { return }

        self.progression = progression
        engine?.start()

        clockSubscription = clock.beats
            .sink { [weak self] event in self?.handleTick(event) }

        isPreviewing = true
        clock.start(bpm: progression.recommendedBPM, timeSignature: .fourFour)
    }

    func previewChord(_ chord: GuitarChord) {
        stopPreview()
        engine?.start()
        // 코드 하나를 한 번 다운으로 긁는다.
        engine?.strum(frets: chord.fingering.frets, direction: .down, velocity: 100, interval: 0.03)
        // 짧게 울리고 스스로 꺼진 것으로 친다 — 다음 탭이 다시 켠다.
        isPreviewing = false
    }

    func stopPreview() {
        clock.stop()
        clockSubscription = nil
        engine?.stopAllStrings()
        isPreviewing = false
        progression = nil
    }

    // MARK: - 내부

    private func handleTick(_ event: BeatEvent) {
        guard let progression else { return }

        let bar = event.tickIndex / max(subdivisionsPerBar, 1)

        // 정해둔 횟수만큼 돌면 끝낸다.
        if bar >= progression.totalBars * previewLoopCount {
            stopPreview()
            return
        }

        let tickInBar = event.tickIndex % subdivisionsPerBar
        guard stepTicks.contains(tickInBar) else { return }

        guard let chord = progression.loopedChord(atBar: bar) else { return }
        let velocity: UInt8 = event.isDownbeat ? 108 : 88
        engine?.strum(frets: chord.fingering.frets, direction: .down, velocity: velocity, interval: 0.03)
    }
}
