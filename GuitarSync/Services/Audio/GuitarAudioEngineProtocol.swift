import Foundation

/// 기타 오디오 엔진의 공통 인터페이스.
///
/// 뷰모델은 구체적인 엔진 구현(`NativeAudioEngine` / `AudioKitAudioEngine`)을 알 필요 없이
/// 이 프로토콜에만 의존한다. 덕분에 런타임에 엔진을 갈아끼워 A/B 비교하기 쉽다.
@MainActor
protocol GuitarAudioEngineProtocol: AnyObject {
    func start()
    func stop()
    func pluckString(stringIndex: Int, fretNumber: Int, velocity: UInt8)
    func pluckStringSequence(_ stringIndices: [Int], frets: [Int], baseVelocity: UInt8, interval: TimeInterval)
    func strum(frets: [Int], direction: StrumDirection, velocity: UInt8, interval: TimeInterval)
    func stopString(stringIndex: Int)
    func stopAllStrings()
}
