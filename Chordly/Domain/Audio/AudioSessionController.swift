import AVFoundation
import Foundation
#if os(iOS)
import UIKit
#endif

/// 세션 감시자가 엔진에게 요구하는 최소 능력. (ROADMAP 태스크 A4)
///
/// 네 가지를 구분하는 이유는 **복구 비용이 서로 다르기 때문**이다.
/// 이어폰이 빠진 건 울리던 소리만 끊으면 되지만, 미디어 서비스가 리셋되면
/// 엔진 객체 자체가 무효라 전부 새로 만들어야 한다.
@MainActor
protocol AudioSessionRecoverable: AnyObject {
    /// 울리던 노트만 즉시 끊는다. **엔진은 살려 둔다** — 다음 터치는 바로 소리가 나야 한다.
    func cutSoundingNotes()

    /// 엔진을 멈춘다. 시스템이 이미 세션을 뺏어간 상태다.
    func suspendForInterruption()

    /// 엔진을 다시 구동한다. 그래프는 그대로 살아 있다고 가정한다.
    func resumeAfterInterruption()

    /// 그래프가 통째로 무효화됐다. 엔진 객체부터 새로 만든다.
    func rebuildAudioGraph()
}

/// `AVAudioSession`을 설정하고, 소리가 죽는 상황을 감시해 엔진을 되살린다. (ROADMAP 태스크 A4)
///
/// ## 이게 없으면 무슨 일이 생기나
///
/// 전화 한 통을 받고 나면 **앱은 멀쩡한데 소리만 조용히 안 난다.** 사용자는 이유를 모른 채
/// 앱을 껐다 켠다. 오디오 앱에서 가장 흔한 버그이고, 증상이 조용해서 QA에서도 잘 안 잡힌다.
///
/// ## 감시하는 사건 5가지
///
/// | 사건 | 언제 | 대응 |
/// |------|------|------|
/// | 중단(interruption) | 전화·알람·Siri | 시작 시 엔진 정지 → 끝나면 세션 재활성 + 재구동 |
/// | 경로 변경(route change) | 이어폰 꽂고 뺌·블루투스 전환 | 기기가 빠지면 소리만 끊고, 새 경로가 잡히면 재구동 |
/// | 미디어 서비스 리셋 | 시스템 오디오 데몬이 죽었다 살아남 (드묾) | 그래프 전면 재구축 |
/// | 앱 활성화 | 백그라운드에서 복귀 | 세션 재활성 + 재구동 (놓친 중단 종료 알림 대비) |
/// | 앱 비활성화 | 홈으로 나감·전화 화면 | 울리던 소리 끊기 |
///
/// ## 왜 앱 활성화까지 보나
///
/// iOS는 **중단 종료 알림을 안 보내는 경우가 있다.** 특히 중단이 앱 백그라운드 전환과
/// 겹치면 그렇다. 그때 유일하게 믿을 수 있는 신호가 "앱이 다시 활성화됐다"이므로,
/// 이 시점에 무조건 한 번 되살린다. 이미 돌고 있으면 재구동은 무해하다.
@MainActor
final class AudioSessionController {
    private weak var engine: AudioSessionRecoverable?
    private var observers: [NSObjectProtocol] = []

    /// `stop()` 없이 엔진이 사라지는 경로(뷰모델 해제 등)에서도 감시가 남지 않게 한다.
    /// `NotificationCenter`가 등록 블록을 잡고 있어서, 안 지우면 조용히 쌓인다.
    deinit {
        let leftovers = observers
        for token in leftovers {
            NotificationCenter.default.removeObserver(token)
        }
    }

    /// 세션을 설정하고 감시를 시작한다. 같은 엔진으로 여러 번 불러도 안전하다.
    func activate(for engine: AudioSessionRecoverable) {
        self.engine = engine
        configureSession()
        startObserving()
    }

    /// 감시를 멈춘다.
    ///
    /// - Note: 세션을 `setActive(false)`로 내리지는 **않는다.** 화면을 잠깐 벗어났다
    ///   되돌아오는 흐름이 잦은데, 그때마다 세션을 내렸다 올리면 첫 소리가 늦게 난다.
    func deactivate() {
        stopObserving()
        engine = nil
    }

    // MARK: - Session configuration

    /// 카테고리·버퍼 길이를 잡고 세션을 켠다.
    ///
    /// - `.playback` + `.mixWithOthers`: 다른 앱 소리와 공존하되, 무음 스위치에는 영향받지 않는다.
    /// - `setPreferredIOBufferDuration(0.005)`: 터치→소리 지연을 줄이기 위한 5ms 요청.
    ///   **요청일 뿐 보장이 아니다** — 실제 체감 지연은 A2에서 계측한다.
    func configureSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            log("세션 설정 실패: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Observation

    private func startObserving() {
        #if os(iOS)
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        observe(center, AVAudioSession.interruptionNotification, object: session) { [weak self] notification in
            self?.handleInterruption(notification)
        }

        observe(center, AVAudioSession.routeChangeNotification, object: session) { [weak self] notification in
            self?.handleRouteChange(notification)
        }

        // 오디오 데몬이 죽었다 살아난 경우. 기존 엔진·노드·샘플러는 전부 무효다.
        observe(center, AVAudioSession.mediaServicesWereResetNotification, object: session) { [weak self] _ in
            self?.log("미디어 서비스 리셋 — 그래프를 새로 만든다.")
            self?.configureSession()
            self?.engine?.rebuildAudioGraph()
        }

        observe(center, UIApplication.didBecomeActiveNotification, object: nil) { [weak self] _ in
            self?.reactivateAndResume(reason: "앱 활성화")
        }

        observe(center, UIApplication.willResignActiveNotification, object: nil) { [weak self] _ in
            self?.engine?.cutSoundingNotes()
        }
        #endif
    }

    private func stopObserving() {
        for token in observers {
            NotificationCenter.default.removeObserver(token)
        }
        observers.removeAll()
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        object: Any?,
        handler: @escaping @MainActor (Notification) -> Void
    ) {
        let token = center.addObserver(forName: name, object: object, queue: .main) { notification in
            MainActor.assumeIsolated {
                handler(notification)
            }
        }
        observers.append(token)
    }

    // MARK: - Handlers

    #if os(iOS)
    private func handleInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw)
        else {
            return
        }

        switch type {
        case .began:
            // 시스템이 이미 세션을 비활성화했다. 남은 노트를 정리하고 엔진도 내린다.
            log("중단 시작 (전화·Siri·알람)")
            engine?.suspendForInterruption()

        case .ended:
            // Apple 권장은 `.shouldResume`가 있을 때만 재개하는 것이지만, **악기 앱에서는
            // 항상 재개한다.** 사용자가 화면을 보고 있는데 소리만 안 나면 고장으로 느낀다.
            // 플래그는 로그로만 남긴다.
            let options = (notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            reactivateAndResume(
                reason: options.contains(.shouldResume) ? "중단 종료" : "중단 종료(shouldResume 없음)"
            )

        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw)
        else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            // 이어폰이 빠졌다. 그냥 두면 **스피커로 갑자기 크게 울린다.**
            // 엔진은 살려 둬서 다음 터치는 바로 나게 한다.
            log("출력 기기 분리 — 울리던 소리만 끊는다.")
            engine?.cutSoundingNotes()

        case .newDeviceAvailable, .categoryChange, .override, .routeConfigurationChange:
            // 새 경로에서는 하드웨어 포맷이 달라져 엔진이 스스로 멈춰 있을 수 있다.
            reactivateAndResume(reason: "출력 경로 변경")

        default:
            break
        }
    }
    #endif

    private func reactivateAndResume(reason: String) {
        guard let engine else { return }

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            log("\(reason) — 세션 재활성 실패: \(error.localizedDescription)")
        }
        #endif

        log("\(reason) — 엔진 재구동")
        engine.resumeAfterInterruption()
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[AudioSession] \(message)")
        #endif
    }
}
