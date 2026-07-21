import SwiftUI

struct MainInstrumentScreen: View {
    @ObservedObject var viewModel: ScreenshotPrototypeViewModel
    /// 연결·운지 송수신을 담당하는 단일 세션. (모드 C)
    @ObservedObject var peer: PeerConnectViewModel

    @StateObject private var strumViewModel = GuitarStrumViewModel()

    /// 모드 A(넥 + 자동 스트럼). 엔진·운지상태를 하나로 공유해 조립한 컨트롤러.
    @StateObject private var chordMode = ChordModeController()

    /// 모드 B의 자동 왼손 — 고른 코드진행을 BPM에 맞춰 짚어준다. 스트럼 화면이 이 코드로 소리 낸다.
    @StateObject private var strumProgression = ChordProgressionPlayer()

    /// 스트로크 선택(U4)에서 고른 주법. 재생 시 자동 스트럼이 이걸 긁는다.
    var selectedStrumPattern: StrumPattern?

    /// 진행 선택(U5)에서 고른 코드진행. 스트럼 모드에서 재생하면 이게 BPM대로 자동으로 짚힌다.
    var selectedProgression: ChordProgression?

    /// 연결 버튼(🔗)을 눌렀을 때. 기기 찾기 화면으로 이동한다 (AppRootView가 라우팅).
    var onPeerConnect: () -> Void = {}

    /// 코드/스트로크 모드를 바꿀 때. **라우터 route까지 바꾼다** — 안 그러면 뒤로가기가 넥으로 샌다.
    var onModeChange: (PrototypeMode) -> Void = { _ in }

    /// 이 기기. iPad는 모드 토글을 숨기고 항상 스트로크만 한다.
    var deviceType: DeviceType = DeviceInfoProvider.currentDeviceType

    private var isPad: Bool { deviceType == .iPad }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            instrument

            TopControlBar(
                mode: viewModel.mode,
                isPlaying: viewModel.isPlaying,
                isExpanded: viewModel.isControlBarExpanded,
                peerButtonState: peerButtonState,
                actionTitle: viewModel.actionTitle,
                showsModeToggle: !isPad,
                onModeChange: onModeChange,
                onPeer: onPeerConnect,
                onAction: viewModel.openActionScreen,
                onTogglePlayback: viewModel.togglePlayback,
                onToggleBPM: viewModel.toggleBPM,
                onToggleControls: viewModel.toggleControls
            )
            .padding(.top, 20)
            .padding(.leading, 20)
            .padding(.trailing, 60)

            if viewModel.showBPM && viewModel.isControlBarExpanded {
                BPMPopover(bpm: $viewModel.bpm)
                    .padding(.top, 88)
                    .padding(.trailing, 162)
            }

            #if DEBUG
            if viewModel.mode == .strum {
                DebugAudioEngineToggle(viewModel: strumViewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 20)
                    .padding(.bottom, 20)
            }
            #endif
        }
        // BPM을 바꾸면 도는 자동 연주(코드 모드=주법 / 스트럼 모드=진행)를 새 속도로 다시 맞춘다.
        .onChange(of: viewModel.bpm) { _, _ in
            switch viewModel.mode {
            case .chord: refreshChordStrum()
            case .strum: refreshStrumProgression()
            }
        }
        // 연결 여부에 따라 자동 연주를 껐다(모드 C) 켰다(모드 A·B) 한다.
        .onChange(of: peer.isConnected) { _, connected in
            chordMode.setConnected(connected)
            switch viewModel.mode {
            case .chord: refreshChordStrum()
            case .strum: refreshStrumProgression()
            }
        }
    }

    /// 코드 모드(모드 A)의 자동 주법을 지금 조건에 맞게 켜거나 끈다.
    ///
    /// **재생 버튼과 무관하다** — 코드 화면에 있고 연결 안 됐으면 늘 돈다. 그래야 "코드를 짚어놓고
    /// 있으면 고른 주법이 BPM대로 자동으로 긁으며 그 코드로 소리 나는" 연습이 된다 (짚기 자체는 무음).
    /// 연결됐을 땐(모드 C) 돌리지 않는다 — 소리는 iPad에서 나기 때문.
    private func refreshChordStrum() {
        guard !peer.isConnected else {
            chordMode.stop()
            return
        }
        chordMode.play(pattern: patternToPlay, bpm: viewModel.bpm)
    }

    /// 스트럼 모드(모드 B)의 자동 코드진행을 지금 조건에 맞게 켜거나 끈다.
    ///
    /// **재생 버튼과 무관하다** — 스트럼 화면에 있고 진행을 골랐고 연결 안 됐으면 늘 돈다.
    /// 그래야 "코드진행을 골라놓고 계속 스트로크하면 시간에 맞춰 코드가 자동으로 바뀌는" 연습이 된다.
    /// 연결됐을 땐(모드 C) 돌리지 않는다 — 그땐 왼손 운지가 iPhone에서 네트워크로 오기 때문.
    private func refreshStrumProgression() {
        guard !peer.isConnected, let progression = selectedProgression else {
            strumProgression.stop()
            return
        }
        strumProgression.start(progression: progression, bpm: viewModel.bpm, looping: true)
        // 첫 코드를 즉시 반영해 둔다 (클럭 첫 틱을 기다리지 않고 바로 그 코드로 소리 나게).
        if let first = progression.chord(atBar: 0) {
            strumViewModel.updateFingering(first.fingering.frets)
        }
    }

    /// 지금 자동 스트럼에 쓸 주법. 고른 게 없으면 첫 프리셋 → 최후 기본값.
    private var patternToPlay: StrumPattern {
        selectedStrumPattern ?? StrumPatternLibrary().presets.first ?? .fallback
    }

    private var peerButtonState: PrototypePeerButtonState {
        peer.isConnected ? .connected : .disconnected
    }

    @ViewBuilder
    private var instrument: some View {
        switch viewModel.mode {
        case .chord:
            // 모드 A/C — 넥으로 짚는다. **짚기 자체는 무음**이고, 단독이면 고른 주법이 BPM대로
            // 자동으로 긁으며 그 코드로 소리 낸다 (스트로크 모드가 진행을 자동으로 돌리는 것과 대칭).
            // 연결되면 자동 스트럼을 멈추고, 운지는 상대(iPad)로 전송돼 거기서 소리가 난다.
            NeckScreen(
                viewModel: chordMode.neck,
                onFingeringChanged: { peer.sendFingering($0) }
            )
                .ignoresSafeArea()
                .onAppear {
                    chordMode.start()
                    chordMode.setConnected(peer.isConnected)
                    refreshChordStrum()   // 단독이면 자동 주법이 바로 돌기 시작
                }
                // 주법을 새로 고르면 그 주법으로 바로 갈아탄다.
                .onChange(of: selectedStrumPattern) { _, _ in
                    refreshChordStrum()
                }
                .onDisappear {
                    chordMode.end()
                    viewModel.isPlaying = false
                }
        case .strum:
            // 스트럼 — 단독(모드 B)이거나 연결됨(모드 C). 연결되면 상대(iPhone)가 짚은 운지로 소리 난다.
            // 그리고 내가 튕길 때마다 그 세기를 상대(iPhone)로 보내 거기서 진동이 나게 한다.
            GuitarStrumView(viewModel: strumViewModel)
                .ignoresSafeArea()
                .onAppear {
                    // 연결됐으면 상대 운지로, 아니면 고른 진행을 자동으로 돌린다.
                    if peer.isConnected {
                        strumViewModel.updateFingering(peer.receivedFingering.frets)
                    } else {
                        refreshStrumProgression()
                    }
                }
                // 모드 C: 상대(iPhone)가 짚은 운지로 소리 난다.
                .onChange(of: peer.receivedFingering) { _, fingering in
                    guard peer.isConnected else { return }
                    strumViewModel.updateFingering(fingering.frets)
                }
                // 진행을 새로 고르면 그 진행으로 바로 갈아탄다.
                .onChange(of: selectedProgression) { _, _ in
                    refreshStrumProgression()
                }
                // 모드 B: 자동 코드진행이 BPM대로 코드를 바꾸면 그 코드로 소리 난다.
                .onReceive(strumProgression.chordChanged) { chord in
                    guard !peer.isConnected else { return }
                    strumViewModel.updateFingering(chord.fingering.frets)
                }
                // 내가 튕길 때마다 그 세기를 상대(iPhone)로 보내 거기서 진동이 나게 한다. (모드 C)
                .onReceive(strumViewModel.strumPerformed) { velocity in
                    peer.sendStrumHaptic(velocity: velocity)
                }
                .onDisappear { strumProgression.stop() }
        }
    }
}
