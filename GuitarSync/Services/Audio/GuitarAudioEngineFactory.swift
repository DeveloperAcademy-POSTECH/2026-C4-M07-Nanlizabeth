import Foundation

/// 빌드 설정에 따라 기본 오디오 엔진 구현을 생성한다.
///
/// 컴파일 조건 분기(`#if`)는 이 파일 한 곳에만 둔다. 나머지 코드는 전부
/// `GuitarAudioEngineProtocol`에만 의존하므로, 최종적으로 한 엔진만 쓰기로 결정하면
/// 여기와 해당 엔진 파일만 정리하면 된다.
enum GuitarAudioEngineFactory {
    @MainActor
    static func makeDefault() -> GuitarAudioEngineProtocol {
        #if USE_AUDIOKIT && canImport(AudioKit)
        return AudioKitAudioEngine()
        #else
        return NativeAudioEngine()
        #endif
    }
}
