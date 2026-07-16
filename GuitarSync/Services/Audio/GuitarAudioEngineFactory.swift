import Foundation

/// 사용할 오디오 엔진의 종류.
enum AudioEngineKind: String, CaseIterable {
    case native = "Native"
    case audioKit = "AudioKit"

    var displayName: String { rawValue }
}

/// 빌드 설정/종류에 따라 오디오 엔진 구현을 생성한다.
///
/// 컴파일 조건 분기(`#if`)는 이 파일 한 곳에만 둔다. 나머지 코드는 전부
/// `GuitarAudioEngineProtocol`에만 의존하므로, 최종적으로 한 엔진만 쓰기로 결정하면
/// 여기와 해당 엔진 파일만 정리하면 된다.
enum GuitarAudioEngineFactory {
    /// AudioKit 패키지가 프로젝트에 연결되어 있는지 여부.
    static var isAudioKitAvailable: Bool {
        #if canImport(AudioKit)
        return true
        #else
        return false
        #endif
    }

    /// 앱을 켤 때 처음 사용할 기본 엔진 종류. (`USE_AUDIOKIT` 플래그로 결정)
    static var defaultKind: AudioEngineKind {
        #if USE_AUDIOKIT && canImport(AudioKit)
        return .audioKit
        #else
        return .native
        #endif
    }

    /// 지정한 종류의 엔진을 생성한다. AudioKit이 없으면 네이티브로 대체한다.
    @MainActor
    static func make(_ kind: AudioEngineKind) -> GuitarAudioEngineProtocol {
        switch kind {
        case .native:
            return NativeAudioEngine()
        case .audioKit:
            #if canImport(AudioKit)
            return AudioKitAudioEngine()
            #else
            return NativeAudioEngine()
            #endif
        }
    }

    @MainActor
    static func makeDefault() -> GuitarAudioEngineProtocol {
        make(defaultKind)
    }
}
