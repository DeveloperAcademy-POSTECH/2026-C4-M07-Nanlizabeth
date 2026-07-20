import Foundation

/// 멀티피어로 들어온 운지 메시지를 `RemoteFingeringSource`에 흘려 넣는 다리. (ROADMAP 태스크 N1)
///
/// 이걸 끼우면 **코디네이터는 원격인지도 모른 채** 동작한다 — 왼손 플러그가 사람인지 자동인지
/// 네트워크인지는 코디네이터의 관심사가 아니다 (ARCHITECTURE §3.7).
///
/// ## ⚠️ 메시지 핸들러는 하나뿐이다
///
/// `MultipeerServiceProtocol.onMessageReceived`는 **하나짜리 콜백**이라, 이 다리를 만들면
/// 그 콜백을 차지한다. 그래서 합주 세션(모드 C)이 멀티피어 인스턴스를 **전용으로** 소유해야 한다.
/// 여러 소비자가 필요해지면 서비스 쪽을 브로드캐스트(퍼블리셔)로 바꾸는 게 맞다 — 지금은 불필요.
@MainActor
final class RemoteFingeringBridge {
    private let target: RemoteFingeringSource

    init(multipeer: MultipeerServiceProtocol, target: RemoteFingeringSource) {
        self.target = target
        // `MultipeerService`는 이미 콜백을 메인에서 부른다(구현 확인). 그래서 홉 없이 바로 반영한다 —
        // 한 틱 늦추면 "받자마자 긁었을 때" 옛 운지로 소리 날 수 있다.
        multipeer.onMessageReceived = { [weak target] message, _ in
            MainActor.assumeIsolated {
                guard message.type == .fingering, let frets = message.frets else { return }
                target?.update(GuitarFingering(frets: frets))
            }
        }
    }
}

/// 내 운지를 상대에게 보내는 쪽. **모드 C의 iPhone(짚기 담당).** (ROADMAP 태스크 N1)
///
/// 같은 운지는 다시 보내지 않는다 — 손가락을 얹고 있는 동안 메시지가 쏟아지면 연결이 못 버틴다.
@MainActor
final class RemoteFingeringSender {
    private let multipeer: MultipeerServiceProtocol
    private var lastSent: GuitarFingering?

    init(multipeer: MultipeerServiceProtocol) {
        self.multipeer = multipeer
    }

    /// 넥의 운지가 바뀔 때마다 부른다.
    func send(_ fingering: GuitarFingering) {
        guard fingering != lastSent else { return }
        lastSent = fingering
        multipeer.send(.fingering(fingering.frets))
    }
}
