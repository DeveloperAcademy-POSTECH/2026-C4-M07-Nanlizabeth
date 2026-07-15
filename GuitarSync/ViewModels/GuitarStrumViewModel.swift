import Combine
import CoreGraphics
import Foundation

@MainActor
final class GuitarStrumViewModel: ObservableObject {
    @Published private(set) var currentFingering: GuitarFingering
    @Published var layoutConfiguration: StrumLayoutConfiguration
    @Published var directionMapping: StrumDirectionMapping
    @Published var debugOverlayEnabled: Bool
    @Published private(set) var debugState = GuitarStrumDebugState()

    private var audioEngine: GuitarAudioEngineProtocol
    private var startAxisValue: CGFloat?
    private var previousAxisValue: CGFloat?
    private var previousInputTime: TimeInterval?
    private var previousStringIndex: Int?

    init() {
        self.currentFingering = GuitarFingering()
        self.layoutConfiguration = StrumLayoutConfiguration()
        self.directionMapping = StrumDirectionMapping()
        self.debugOverlayEnabled = false
        self.audioEngine = GuitarAudioEngineFactory.makeDefault()
    }

    init(
        layoutConfiguration: StrumLayoutConfiguration,
        directionMapping: StrumDirectionMapping,
        debugOverlayEnabled: Bool
    ) {
        self.currentFingering = GuitarFingering()
        self.layoutConfiguration = layoutConfiguration
        self.directionMapping = directionMapping
        self.debugOverlayEnabled = debugOverlayEnabled
        self.audioEngine = GuitarAudioEngineFactory.makeDefault()
    }

    init(
        currentFingering: GuitarFingering,
        layoutConfiguration: StrumLayoutConfiguration,
        directionMapping: StrumDirectionMapping,
        debugOverlayEnabled: Bool,
        audioEngine: GuitarAudioEngineProtocol
    ) {
        self.currentFingering = currentFingering
        self.layoutConfiguration = layoutConfiguration
        self.directionMapping = directionMapping
        self.debugOverlayEnabled = debugOverlayEnabled
        self.audioEngine = audioEngine
    }

    func startAudio() {
        audioEngine.start()
    }

    func stopAudio() {
        audioEngine.stop()
    }

    /// 런타임에 오디오 엔진을 교체한다. (예: AudioKit ↔ 네이티브 A/B 비교용 토글)
    func switchAudioEngine(to engine: GuitarAudioEngineProtocol) {
        audioEngine.stop()
        audioEngine = engine
        audioEngine.start()
    }

    func updateFingering(_ frets: [Int]) {
        currentFingering = GuitarFingering(frets: frets)
    }

    func pluckString(_ stringIndex: Int, velocity: UInt8 = 96) {
        guard let fret = currentFingering.fret(for: stringIndex) else { return }
        audioEngine.pluckString(
            stringIndex: stringIndex,
            fretNumber: fret,
            velocity: velocity
        )
    }

    func handleInputChanged(location: CGPoint, in size: CGSize) {
        let currentTime = ProcessInfo.processInfo.systemUptime
        let currentAxisValue = axisValue(from: location, axis: layoutConfiguration.strumAxis)
        if startAxisValue == nil {
            startAxisValue = currentAxisValue
        }

        let rawDirection = rawDirection(currentAxisValue: currentAxisValue)
        let mappedDirection = rawDirection.map(directionMapping.direction(for:))
        let currentStringIndex = stringIndex(
            from: location,
            in: size,
            configuration: layoutConfiguration
        )

        debugState = GuitarStrumDebugState(
            axis: layoutConfiguration.strumAxis,
            axisValue: currentAxisValue,
            stringIndex: currentStringIndex,
            rawDirection: rawDirection,
            direction: mappedDirection,
            reverseStringMapping: layoutConfiguration.reverseStringMapping
        )

        guard let currentStringIndex else {
            previousAxisValue = currentAxisValue
            previousInputTime = currentTime
            return
        }

        let dynamics = strumDynamics(
            currentAxisValue: currentAxisValue,
            currentTime: currentTime
        )
        playCrossedStrings(endingAt: currentStringIndex, dynamics: dynamics)
        previousStringIndex = currentStringIndex
        previousAxisValue = currentAxisValue
        previousInputTime = currentTime
    }

    func handleInputEnded() {
        startAxisValue = nil
        previousAxisValue = nil
        previousInputTime = nil
        previousStringIndex = nil
    }

    func strum(direction: StrumDirection, velocity: UInt8 = 96, interval: TimeInterval = 0.035) {
        audioEngine.strum(
            frets: currentFingering.frets,
            direction: direction,
            velocity: velocity,
            interval: interval
        )
    }

    private func playCrossedStrings(endingAt currentStringIndex: Int, dynamics: StrumDynamics) {
        guard let previousStringIndex else {
            pluckString(currentStringIndex, velocity: dynamics.velocity)
            return
        }

        guard previousStringIndex != currentStringIndex else {
            return
        }

        let step = currentStringIndex > previousStringIndex ? 1 : -1
        var stringIndex = previousStringIndex + step
        var crossedStringIndices: [Int] = []

        while true {
            crossedStringIndices.append(stringIndex)
            if stringIndex == currentStringIndex { break }
            stringIndex += step
        }

        audioEngine.pluckStringSequence(
            crossedStringIndices,
            frets: currentFingering.frets,
            baseVelocity: dynamics.velocity,
            interval: dynamics.interval
        )
    }

    private func rawDirection(currentAxisValue: CGFloat) -> RawStrumDirection? {
        guard let startAxisValue, currentAxisValue != startAxisValue else { return nil }
        return currentAxisValue > startAxisValue ? .forward : .backward
    }

    private func strumDynamics(
        currentAxisValue: CGFloat,
        currentTime: TimeInterval
    ) -> StrumDynamics {
        guard let previousAxisValue, let previousInputTime else {
            return StrumDynamics(velocity: 86, interval: 0.020)
        }

        let distance = abs(Double(currentAxisValue - previousAxisValue))
        let elapsed = max(currentTime - previousInputTime, 0.008)
        let pointsPerSecond = distance / elapsed
        let normalizedSpeed = min(max((pointsPerSecond - 180) / 1_700, 0), 1)
        let velocity = UInt8(72 + Int(normalizedSpeed * 46))
        let interval = 0.030 - (normalizedSpeed * 0.018)

        return StrumDynamics(velocity: velocity, interval: interval)
    }
}

struct GuitarStrumDebugState: Equatable {
    var axis: StrumAxis = .y
    var axisValue: CGFloat = 0
    var stringIndex: Int?
    var rawDirection: RawStrumDirection?
    var direction: StrumDirection?
    var reverseStringMapping = false
}

private struct StrumDynamics {
    let velocity: UInt8
    let interval: TimeInterval
}
