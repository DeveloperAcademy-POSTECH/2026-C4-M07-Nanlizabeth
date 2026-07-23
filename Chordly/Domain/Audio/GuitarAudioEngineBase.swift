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

    /// 전화·이어폰 분리 같은 사건에서 엔진을 되살리는 감시자. (ROADMAP 태스크 A4)
    private let sessionController = AudioSessionController()

    // MARK: - Lifecycle

    func start() {
        // 감시를 먼저 건다 — 그래야 셋업 도중에 들어온 중단도 놓치지 않는다.
        sessionController.activate(for: self)
        setupEngine()
        performStart()
    }

    func stop() {
        sessionController.deactivate()
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

    /// 엔진이 실제로 돌고 있는지. **재개가 성공했는지 판단하는 데 쓴다.**
    ///
    /// 기본값이 `false`라 오버라이드를 잊으면 재개할 때마다 그래프를 새로 만든다 —
    /// 느릴 뿐 소리는 나므로, 조용히 죽는 것보다 안전한 쪽으로 기울여 둔다.
    var isEngineRunning: Bool { false }

    /// 그래프를 통째로 새로 만든다. (미디어 서비스 리셋·재개 실패 시)
    ///
    /// 기본 구현은 기존 훅만 다시 밟는다. **엔진 객체 자체가 무효가 되는 프레임워크**
    /// (AVAudioEngine·AudioKit 둘 다 해당)는 서브클래스에서 오버라이드해
    /// 객체를 새로 만든 뒤 `super`를 부르지 말고 직접 셋업해야 한다.
    func rebuildEngine() {
        performStop()
        isSetUp = false
        setupEngine()
        performStart()
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

    /// 세션 설정은 `AudioSessionController`가 단독으로 책임진다. (ROADMAP 태스크 A4)
    ///
    /// 카테고리·버퍼 길이를 여기저기서 바꾸면 나중에 누가 마지막으로 덮었는지 추적이 안 되므로,
    /// **설정하는 곳을 한 군데로 묶어 뒀다.**
    func configureAudioSession() {
        sessionController.configureSession()
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

// MARK: - AudioSessionRecoverable

/// 소리가 죽는 상황에서의 복구 절차. 두 엔진이 그대로 물려받는다. (ROADMAP 태스크 A4)
extension GuitarAudioEngineBase: AudioSessionRecoverable {
    func cutSoundingNotes() {
        stopAllStrings()
    }

    func suspendForInterruption() {
        stopAllStrings()
        performStop()
    }

    func resumeAfterInterruption() {
        // 셋업 전이면 정상 경로로 처음부터 켠다.
        guard isSetUp else {
            start()
            return
        }

        performStart()

        // 경로가 바뀌어 하드웨어 포맷이 달라지면 기존 연결이 무효라 `start()`가 조용히 실패한다.
        // **여기서 확인하지 않으면 소리가 안 나는 채로 앱이 멀쩡해 보인다.**
        guard !isEngineRunning else { return }

        logAudioError("재개 실패 — 그래프를 새로 만든다.")
        rebuildEngine()
    }

    func rebuildAudioGraph() {
        stopAllStrings()
        rebuildEngine()
    }
}
