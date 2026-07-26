import Combine
import Foundation

/// 첫 온보딩 페이지에만 흐르는 잔잔한 기타 루프.
///
/// 한 가지 패턴을 반복하지 않고 아르페지오와 가벼운 스트럼을 번갈아 연주한다.
/// 페이지를 넘기면 `stop()`이 즉시 클럭과 잔향을 정리한다.
@MainActor
final class OnboardingGuitarLoopPlayer: ObservableObject {
    private let engine: GuitarAudioEngineProtocol
    private let clock: BeatClockProtocol
    private var beatSubscription: AnyCancellable?

    private let progression: [GuitarChord] = [
        "C", "G", "Am", "Em", "Fmaj7", "C", "Dm7", "G7",
    ]

    init(
        engine: GuitarAudioEngineProtocol? = nil,
        clock: BeatClockProtocol? = nil
    ) {
        self.engine = engine ?? GuitarAudioEngineFactory.makeDefault()
        self.clock = clock ?? BeatClock()
    }

    func play() {
        guard !clock.isRunning else { return }

        engine.start()
        beatSubscription = clock.beats
            .sink { [weak self] event in
                self?.play(event)
            }
        clock.start(bpm: 82, timeSignature: .fourFour)
    }

    func stop() {
        clock.stop()
        beatSubscription = nil
        engine.stopAllStrings()
        engine.stop()
    }

    private func play(_ event: BeatEvent) {
        let ticksPerBar = TimeSignature.fourFour.subdivisionsPerBar
        let bar = event.tickIndex / ticksPerBar
        let tick = event.tickIndex % ticksPerBar
        let chord = progression[bar % progression.count]

        if bar.isMultiple(of: 2) {
            playArpeggio(chord, tick: tick)
        } else {
            playSoftStrum(chord, tick: tick)
        }
    }

    private func playArpeggio(_ chord: GuitarChord, tick: Int) {
        let fingering = chord.fingering
        let audible = fingering.frets.indices.filter { fingering.isAudible(stringIndex: $0) }
        guard let bass = audible.first else { return }

        let upper = audible.filter { $0 != bass }
        guard !upper.isEmpty else { return }

        let tickPattern = [0, 2, 4, 6, 8, 10, 12, 14]
        guard let noteIndex = tickPattern.firstIndex(of: tick) else { return }

        let stringPattern = [
            bass,
            upper[min(1, upper.count - 1)],
            upper[min(2, upper.count - 1)],
            upper.last!,
            bass,
            upper[min(2, upper.count - 1)],
            upper[min(1, upper.count - 1)],
            upper.last!,
        ]
        let stringIndex = stringPattern[noteIndex]
        let velocity: UInt8 = noteIndex == 0 || noteIndex == 4 ? 78 : 62
        engine.pluckString(
            stringIndex: stringIndex,
            fretNumber: fingering.frets[stringIndex],
            velocity: velocity
        )
    }

    private func playSoftStrum(_ chord: GuitarChord, tick: Int) {
        let event: (StrumDirection, UInt8)?
        switch tick {
        case 0: event = (.down, 82)
        case 4: event = (.down, 58)
        case 6: event = (.up, 50)
        case 8: event = (.down, 70)
        case 12: event = (.down, 56)
        case 14: event = (.up, 48)
        default: event = nil
        }

        guard let event else { return }
        engine.strum(
            frets: chord.fingering.frets,
            direction: event.0,
            velocity: event.1,
            interval: 0.035
        )
    }
}
