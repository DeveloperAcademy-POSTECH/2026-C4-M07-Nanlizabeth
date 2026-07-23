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
    @Published private(set) var audioEngineKind: AudioEngineKind = GuitarAudioEngineFactory.defaultKind

    private var audioEngine: GuitarAudioEngineProtocol

    /// 줄을 튕길 때마다 세기(0~127)를 방송한다. **모드 C에서 iPad가 이걸 iPhone으로 보내
    /// 진동을 일으킨다** — 손맛은 실제로 줄이 튕기는 이쪽(오른손)에서 생기기 때문.
    let strumPerformed = PassthroughSubject<UInt8, Never>()

    /// 손가락별 흔적.
    ///
    /// **손가락마다 따로 들고 있어야 한다.** 하나로 합쳐두면 두 손가락이 서로의 위치를 덮어써서
    /// 엉뚱한 줄이 울리거나 긁는 방향이 뒤집힌다. 진짜 기타는 아르페지오처럼 여러 손가락이
    /// 각자 다른 줄을 동시에 튕기므로, 각자의 궤적을 따로 기억해야 한다.
    private var tracks: [TouchID: StrumTouchTrack] = [:]

    /// 손가락이 줄에 **처음 닿는 순간**의 세기. 아직 속도를 잴 수 없어서 고정값을 쓴다.
    /// (아르페지오처럼 톡 튕기는 동작이 이 값으로 울린다)
    private static let firstContactVelocity: UInt8 = 86

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

    /// 런타임에 두 엔진을 번갈아 교체한다. (A/B 비교용, 주로 디버그 빌드에서 사용)
    func toggleAudioEngine() {
        let next: AudioEngineKind = audioEngineKind == .native ? .audioKit : .native
        switchAudioEngine(to: next)
    }

    /// 런타임에 지정한 종류의 엔진으로 교체한다. 재빌드 없이 즉시 반영된다.
    func switchAudioEngine(to kind: AudioEngineKind) {
        guard kind != audioEngineKind else { return }
        audioEngine.stop()
        audioEngine = GuitarAudioEngineFactory.make(kind)
        audioEngineKind = kind
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

    /// 입력 레이어가 부른다. **지금 줄 위에 닿아 있는 손가락 전부**를 통째로 받는다.
    ///
    /// 손가락마다 따로 처리하므로 아르페지오(여러 줄을 각자 튕기기)와 화음(동시에 긁기)이
    /// 둘 다 된다.
    func handleTouchesChanged(_ touches: [TouchID: CGPoint], band: CGRect) {
        // 뗀 손가락의 흔적부터 지운다.
        tracks = tracks.filter { touches.keys.contains($0.key) }

        let now = ProcessInfo.processInfo.systemUptime

        for (id, location) in touches {
            handleTouch(id: id, location: location, band: band, at: now)
        }

        debugState.activeTouchCount = touches.count
    }

    /// 화면을 벗어나는 등, 손을 다 뗀 것으로 쳐야 할 때.
    func handleInputEnded() {
        tracks.removeAll()
        debugState.activeTouchCount = 0
    }

    private func handleTouch(id: TouchID, location: CGPoint, band: CGRect, at time: TimeInterval) {
        let currentAxisValue = axisValue(from: location, axis: layoutConfiguration.strumAxis)
        let currentStringIndex = stringIndex(
            from: location,
            in: band,
            configuration: layoutConfiguration
        )

        guard var track = tracks[id] else {
            // 이 손가락의 **첫 접촉** — 닿은 줄 하나를 바로 튕긴다.
            tracks[id] = StrumTouchTrack(
                startAxisValue: currentAxisValue,
                previousAxisValue: currentAxisValue,
                previousTime: time,
                previousStringIndex: currentStringIndex
            )

            if let currentStringIndex {
                pluckString(currentStringIndex, velocity: Self.firstContactVelocity)
                strumPerformed.send(Self.firstContactVelocity)
            }

            updateDebugState(track: tracks[id], axisValue: currentAxisValue, stringIndex: currentStringIndex)
            return
        }

        if let currentStringIndex {
            let dynamics = strumDynamics(track: track, currentAxisValue: currentAxisValue, currentTime: time)
            playCrossedStrings(
                from: track.previousStringIndex,
                to: currentStringIndex,
                dynamics: dynamics
            )
            if track.previousStringIndex != currentStringIndex {
                strumPerformed.send(dynamics.velocity)
            }
            track.previousStringIndex = currentStringIndex
        }

        track.previousAxisValue = currentAxisValue
        track.previousTime = time
        tracks[id] = track

        updateDebugState(track: track, axisValue: currentAxisValue, stringIndex: currentStringIndex)
    }

    private func updateDebugState(track: StrumTouchTrack?, axisValue: CGFloat, stringIndex: Int?) {
        // 지역 변수 이름을 메서드와 다르게 둔다 — 같으면 이름이 가려져 호출이 모호해진다.
        let raw = track.flatMap { rawDirection(from: $0.startAxisValue, to: axisValue) }

        debugState = GuitarStrumDebugState(
            axis: layoutConfiguration.strumAxis,
            axisValue: axisValue,
            stringIndex: stringIndex,
            rawDirection: raw,
            direction: raw.map(directionMapping.direction(for:)),
            reverseStringMapping: layoutConfiguration.reverseStringMapping,
            activeTouchCount: tracks.count
        )
    }

    func strum(direction: StrumDirection, velocity: UInt8 = 96, interval: TimeInterval = 0.035) {
        audioEngine.strum(
            frets: currentFingering.frets,
            direction: direction,
            velocity: velocity,
            interval: interval
        )
    }

    /// 손가락이 지나온 줄들을 차례로 울린다. 한 프레임에 여러 줄을 건너뛰었어도 빠짐없이 울린다.
    private func playCrossedStrings(from previousStringIndex: Int?, to currentStringIndex: Int, dynamics: StrumDynamics) {
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

    private func rawDirection(from startAxisValue: CGFloat, to currentAxisValue: CGFloat) -> RawStrumDirection? {
        guard currentAxisValue != startAxisValue else { return nil }
        return currentAxisValue > startAxisValue ? .forward : .backward
    }

    /// 긁는 속도 → 세기·간격. **손가락별 궤적**으로 계산하므로 손가락마다 세기가 다를 수 있다.
    private func strumDynamics(
        track: StrumTouchTrack,
        currentAxisValue: CGFloat,
        currentTime: TimeInterval
    ) -> StrumDynamics {
        let distance = abs(Double(currentAxisValue - track.previousAxisValue))
        let elapsed = max(currentTime - track.previousTime, 0.008)
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
    /// 지금 줄 위에 닿아 있는 손가락 수. **멀티터치가 실제로 먹히는지 눈으로 확인하는 값.**
    var activeTouchCount = 0
}

/// 손가락 하나가 줄 위를 지나가는 동안의 흔적.
private struct StrumTouchTrack {
    /// 이 손가락이 처음 닿은 위치. 긁는 **방향** 판정의 기준점.
    let startAxisValue: CGFloat
    /// 직전 위치·시각. 긁는 **속도**(→세기) 계산에 쓴다.
    var previousAxisValue: CGFloat
    var previousTime: TimeInterval
    /// 직전에 이 손가락이 올라가 있던 줄. 여기서 지금 줄까지가 "지나온 줄"이다.
    var previousStringIndex: Int?
}

private struct StrumDynamics {
    let velocity: UInt8
    let interval: TimeInterval
}
