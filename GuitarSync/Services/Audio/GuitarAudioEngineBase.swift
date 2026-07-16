import AVFoundation
import Foundation

/// 두 오디오 엔진(`NativeAudioEngine`, `AudioKitAudioEngine`)이 공유하는 공통 로직.
///
/// 음 계산·벨로시티·자동 정지 스케줄링처럼 오디오 프레임워크와 무관한 부분을 여기에 모으고,
/// 실제 소리를 내는 부분(`playNote`/`stopNote`)과 엔진 수명주기(`setupEngine`/`performStart`/
/// `performStop`)만 서브클래스가 오버라이드한다. (Template Method 패턴)
@MainActor
class GuitarAudioEngineBase {
    let openStringMIDINotes = [40, 45, 50, 55, 59, 64]
    let noteDuration: TimeInterval = 3.6
    let releaseTimeControl: UInt8 = 72
    let releaseTimeValue: UInt8 = 78

    private var lastPlayedNotes = Array<Int?>(repeating: nil, count: GuitarFingering.stringCount)
    private var scheduledStopWorkItems = Array<DispatchWorkItem?>(repeating: nil, count: GuitarFingering.stringCount)
    var isSetUp = false

    // MARK: - Lifecycle

    func start() {
        setupEngine()
        performStart()
    }

    func stop() {
        stopAllStrings()
        performStop()
    }

    // MARK: - Subclass hooks

    /// 엔진 노드 연결 및 사운드폰트 로딩. 서브클래스에서 반드시 오버라이드한다.
    func setupEngine() {
        fatalError("Subclasses must override setupEngine()")
    }

    /// 실제 오디오 엔진을 구동한다. 서브클래스에서 반드시 오버라이드한다.
    func performStart() {
        fatalError("Subclasses must override performStart()")
    }

    /// 실제 오디오 엔진을 정지한다. 서브클래스에서 반드시 오버라이드한다.
    func performStop() {
        fatalError("Subclasses must override performStop()")
    }

    /// 지정한 현의 샘플러로 노트를 재생한다. 서브클래스에서 반드시 오버라이드한다.
    func playNote(stringIndex: Int, note: Int, velocity: UInt8) {
        fatalError("Subclasses must override playNote(stringIndex:note:velocity:)")
    }

    /// 지정한 현의 샘플러에서 노트를 멈춘다. 서브클래스에서 반드시 오버라이드한다.
    func stopNote(stringIndex: Int, note: Int) {
        fatalError("Subclasses must override stopNote(stringIndex:note:)")
    }

    // MARK: - Note helpers

    func noteNumber(stringIndex: Int, fret: Int) -> Int? {
        guard openStringMIDINotes.indices.contains(stringIndex), (0...24).contains(fret) else {
            return nil
        }

        return openStringMIDINotes[stringIndex] + fret
    }

    // MARK: - Playback

    func pluckString(stringIndex: Int, fretNumber: Int, velocity: UInt8 = 96) {
        guard (0..<GuitarFingering.stringCount).contains(stringIndex), fretNumber >= 0 else { return }
        guard let note = noteNumber(stringIndex: stringIndex, fret: fretNumber) else { return }

        stopString(stringIndex: stringIndex, cancelScheduledStop: true)
        playNote(stringIndex: stringIndex, note: note, velocity: velocity)

        lastPlayedNotes[stringIndex] = note
        scheduleStop(stringIndex: stringIndex, after: noteDuration)
    }

    func pluckStringSequence(
        _ stringIndices: [Int],
        frets: [Int],
        baseVelocity: UInt8 = 96,
        interval: TimeInterval = 0.018
    ) {
        for (offset, stringIndex) in stringIndices.enumerated() {
            let delay = interval * TimeInterval(offset)
            let velocity = sequenceVelocity(
                baseVelocity: baseVelocity,
                stringIndex: stringIndex,
                offset: offset
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                Task { @MainActor in
                    guard let self, frets.indices.contains(stringIndex) else { return }
                    self.pluckString(
                        stringIndex: stringIndex,
                        fretNumber: frets[stringIndex],
                        velocity: velocity
                    )
                }
            }
        }
    }

    func strum(
        frets: [Int],
        direction: StrumDirection,
        velocity: UInt8 = 96,
        interval: TimeInterval = 0.035
    ) {
        let indices: [Int]
        switch direction {
        case .down:
            indices = Array(0..<GuitarFingering.stringCount)
        case .up:
            indices = Array((0..<GuitarFingering.stringCount).reversed())
        }

        pluckStringSequence(
            indices,
            frets: frets,
            baseVelocity: velocity,
            interval: interval
        )
    }

    func stopString(stringIndex: Int) {
        stopString(stringIndex: stringIndex, cancelScheduledStop: true)
    }

    private func stopString(stringIndex: Int, cancelScheduledStop: Bool) {
        guard (0..<GuitarFingering.stringCount).contains(stringIndex),
              lastPlayedNotes.indices.contains(stringIndex)
        else {
            return
        }

        if cancelScheduledStop {
            scheduledStopWorkItems[stringIndex]?.cancel()
            scheduledStopWorkItems[stringIndex] = nil
        }

        guard let note = lastPlayedNotes[stringIndex] else { return }

        stopNote(stringIndex: stringIndex, note: note)

        lastPlayedNotes[stringIndex] = nil
    }

    func stopAllStrings() {
        for stringIndex in 0..<GuitarFingering.stringCount {
            stopString(stringIndex: stringIndex)
        }
    }

    private func scheduleStop(stringIndex: Int, after delay: TimeInterval) {
        guard scheduledStopWorkItems.indices.contains(stringIndex) else { return }

        scheduledStopWorkItems[stringIndex]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.stopString(stringIndex: stringIndex, cancelScheduledStop: false)
                self.scheduledStopWorkItems[stringIndex] = nil
            }
        }

        scheduledStopWorkItems[stringIndex] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    // MARK: - Shared configuration

    func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            logAudioError("Failed to configure audio session: \(error.localizedDescription)")
        }
        #endif
    }

    private func sequenceVelocity(baseVelocity: UInt8, stringIndex: Int, offset: Int) -> UInt8 {
        let textureByString = [3, 1, 2, -1, 0, -2]
        let texture = textureByString.indices.contains(stringIndex) ? textureByString[stringIndex] : 0
        let firstContactAccent = offset == 0 ? 5 : 0
        let rollOff = min(offset * 2, 8)
        return clampedVelocity(Int(baseVelocity) + firstContactAccent + texture - rollOff)
    }

    private func clampedVelocity(_ value: Int) -> UInt8 {
        UInt8(min(max(value, 42), 124))
    }

    func logAudioError(_ message: String) {
        #if DEBUG
        print("[GuitarAudioEngine] \(message)")
        #endif
    }
}
