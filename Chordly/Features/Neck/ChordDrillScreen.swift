import SwiftUI

/// 코드 전환 드릴 화면. (docs/PLAN-chord-drill §4-5)
///
/// **`NeckScreen`을 그대로 품고**(지판·짚은 점·줄 떨림 재사용) 위에 얇은 HUD만 얹는다 —
/// 목표 코드, 진행 표시, 정답 순간 플래시. 짚기 로직·소리 게이트는 `ChordDrillController`가 맡는다.
///
/// - Note: **iPhone 전용 화면**이다. iPad는 왼손을 맡지 않으므로 `AppRoute.isAvailable(on:)`에서 제외된다.
struct ChordDrillScreen: View {
    @Environment(\.landscapeStageSafeAreaInsets) private var stageSafeArea
    /// 연습할 노래. 진입 시 이 노래의 코드 진행으로 드릴을 채운다.
    let song: PracticeSong
    /// 노래 선택으로 들어간 당시의 모드. 코드면 운지, 스트로크면 악보 안내를 보여준다.
    var mode: PrototypeMode = .chord
    @ObservedObject var peer: PeerConnectViewModel

    @EnvironmentObject private var router: AppRouter
    @StateObject private var controller = ChordDrillController()
    @StateObject private var strumViewModel = GuitarStrumViewModel()
    @AppStorage("usesCompactNeckLayout") private var usesCompactNeckLayout = false

    /// 정답 순간 잠깐 켜지는 안내.
    @State private var flashOn = false
    /// 스트로크 모드에서 사용자가 진행한 악보 스텝.
    @State private var strumStepIndex = 0

    private var isPad: Bool { DeviceInfoProvider.currentDeviceType == .iPad }
    private var isConnectedEnsemble: Bool { peer.isConnected }
    /// 악기와 현은 고정한 채 HUD만 화면 최상단 안전영역에 바짝 붙인다.
    private var headerTopInset: CGFloat { max(4, stageSafeArea.top - 16) }

    var body: some View {
        ZStack(alignment: .top) {
            drillBody

            hud
        }
        .onAppear {
            startDrill()
        }
        .onDisappear { endDrill() }
        .onChange(of: controller.correctFlash) { _, _ in showFlash() }
        .onChange(of: controller.currentChord) { _, _ in updateNeckFretOffset() }
        .onChange(of: strumBarIndex) { _, _ in
            guard !isConnectedEnsemble else { return }
            strumViewModel.updateFingering(currentStrumChord.fingering.frets)
        }
        .onChange(of: peer.receivedFingering) { _, fingering in
            guard mode == .strum, isConnectedEnsemble else { return }
            strumViewModel.updateFingering(fingering.frets)
        }
        .onChange(of: peer.sharedSongStep) { _, step in
            syncSharedProgress(step)
        }
        .onReceive(strumViewModel.strumInputPerformed) { event in
            handleStrumInput(event)
        }
        .onReceive(strumViewModel.strumPerformed) { velocity in
            if isConnectedEnsemble {
                peer.sendStrumHaptic(velocity: velocity)
            }
        }
    }

    // MARK: - HUD

    private var hud: some View {
        VStack(spacing: 6) {
            header
            if mode == .chord {
                flashLabel
            }
        }
        .padding(.top, headerTopInset)
        .stageSafeAreaHorizontalPadding(minimum: 16)
    }

    @ViewBuilder
    private var drillBody: some View {
        switch mode {
        case .chord:
            NeckScreen(
                viewModel: controller.neck,
                onFingeringChanged: { fingering in
                    guard isConnectedEnsemble else { return }
                    let voicing = ChordVoicingResolver.resolvedVoicing(for: fingering) ?? fingering
                    peer.sendFingering(voicing)
                },
                targetFingering: visibleTargetFingering,
                targetFingers: controller.currentChord.fingers,
                targetGuideRotationDegrees: 180,
                excludedHitRegions: headerExcludedHitRegions,
                usesCompactLayout: usesCompactNeckLayout
            )
            .ignoresSafeArea()
        case .strum:
            GuitarStrumView(
                viewModel: strumViewModel,
                isPad: isPad,
                excludedHitRegions: headerExcludedHitRegions
            )
                .ignoresSafeArea()
                .overlay {
                    StrumDrillGuideOverlay(
                        step: currentStrumStep,
                        chord: currentStrumChord,
                        isPad: isPad
                    )
                    .allowsHitTesting(false)
                }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            backButton

            Text(song.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.gsTextPrimary)
                .lineLimit(1)
                .frame(
                    minWidth: isPad ? 110 : 76,
                    maxWidth: isPad ? 180 : 128,
                    alignment: .leading
                )

            DrillHeaderScoreStrip(
                mode: mode,
                song: song,
                activeBarIndex: mode == .chord ? controller.position : strumBarIndex,
                activeStepIndex: currentPatternStepIndex
            )
            .frame(maxWidth: .infinity)
        }
        .frame(height: 46)
    }

    private var headerExcludedHitRegions: [CGRect] {
        [
            CGRect(
                x: 0,
                y: 0,
                width: isPad ? LayoutTokens.padStage.width : LayoutTokens.phoneStage.width,
                height: max(58, headerTopInset + 48)
            )
        ]
    }

    private var backButton: some View {
        LiquidGlassIconButton(systemName: "chevron.left") {
            router.back()
        }
        .accessibilityLabel("뒤로")
    }

    private var flashLabel: some View {
        Text("좋아요! 다음 코드로")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.gsOnAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.gsAccent))
            .opacity(flashOn ? 1 : 0)
            .scaleEffect(flashOn ? 1 : 0.9)
    }

    private func showFlash() {
        withAnimation(.easeOut(duration: 0.15)) { flashOn = true }
        Task {
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.easeIn(duration: 0.2)) { flashOn = false }
        }
    }

    // MARK: - 진행

    private var currentPatternStepIndex: Int {
        currentStrumPosition.step
    }

    private var strumBarIndex: Int {
        currentStrumPosition.bar
    }

    private var currentStrumChord: GuitarChord {
        guard song.chords.indices.contains(strumBarIndex) else { return song.drill.current }
        return song.chords[strumBarIndex]
    }

    private var currentStrumStep: PickPattern.Step {
        let pattern = song.pick(at: strumBarIndex)
        guard pattern.steps.indices.contains(currentPatternStepIndex) else { return .rest }
        return pattern.steps[currentPatternStepIndex]
    }

    private var currentStrumPosition: (bar: Int, step: Int) {
        songPosition(for: strumStepIndex)
    }

    private func songPosition(for globalStep: Int) -> (bar: Int, step: Int) {
        guard !song.chords.isEmpty else { return (0, 0) }
        let total = max(totalStrumSteps, 1)
        var remaining = max(0, globalStep) % total

        for barIndex in song.chords.indices {
            let stepCount = max(song.pick(at: barIndex).steps.count, 1)
            if remaining < stepCount {
                return (barIndex, remaining)
            }
            remaining -= stepCount
        }

        return (0, 0)
    }

    private var totalStrumSteps: Int {
        song.chords.indices.reduce(0) { total, index in
            total + max(song.pick(at: index).steps.count, 1)
        }
    }

    private var currentChordFretOffset: Int {
        fretOffset(for: controller.currentChord.fingering)
    }

    private var visibleTargetFingering: GuitarFingering {
        shiftedTargetFingering(controller.currentChord.fingering, offset: currentChordFretOffset)
    }

    private func startDrill() {
        switch mode {
        case .chord:
            controller.load(song.drill)
            controller.setExternallyAdvanced(isConnectedEnsemble)
            updateNeckFretOffset()
            controller.start()
            if !isConnectedEnsemble {
                controller.play(pick: song.pick, barPicks: song.barPicks)
            }
        case .strum:
            strumStepIndex = isConnectedEnsemble ? peer.sharedSongStep : 0
            let fingering = isConnectedEnsemble ? peer.receivedFingering : currentStrumChord.fingering
            strumViewModel.updateFingering(fingering.frets)
        }
    }

    private func endDrill() {
        controller.end()
        strumViewModel.stopAudio()
    }

    private func updateNeckFretOffset() {
        guard mode == .chord else { return }
        controller.neck.setFretOffset(currentChordFretOffset)
    }

    private func fretOffset(for fingering: GuitarFingering) -> Int {
        let fretted = fingering.frets.filter { $0 >= 1 }
        guard let maxFret = fretted.max(), maxFret > NeckGeometry.fretCount else { return 0 }
        return maxFret - NeckGeometry.fretCount
    }

    private func shiftedTargetFingering(_ fingering: GuitarFingering, offset: Int) -> GuitarFingering {
        guard offset > 0 else { return fingering }
        return GuitarFingering(
            frets: fingering.frets.map { fret in
                fret >= 1 ? fret - offset : fret
            }
        )
    }

    private func handleStrumInput(_ event: StrumInputEvent) {
        guard mode == .strum,
              !song.pick.steps.isEmpty,
              hasPlayableChord,
              matchesCurrentStep(event)
        else { return }

        advanceStrumStep()
    }

    private func advanceStrumStep() {
        withAnimation(.snappy) {
            strumStepIndex += 1
            skipRestSteps()
        }
        if isConnectedEnsemble {
            peer.sendSharedSongProgress(step: strumStepIndex)
        }
    }

    private func skipRestSteps() {
        guard totalStrumSteps > 0 else { return }

        for _ in 0..<totalStrumSteps {
            if currentStrumStep != .rest { return }
            strumStepIndex += 1
        }
    }

    private func matchesCurrentStep(_ event: StrumInputEvent) -> Bool {
        switch (currentStrumStep, event) {
        case (.bass, let .pluck(stringIndex)):
            return stringIndex == currentStrumChord.fingering.lowestAudibleString
        case let (.pluck(expected), .pluck(actual)):
            return expected == actual
        case let (.strum, .strum(from, to, direction)):
            let coveredLowString = min(from, to) == 0
            let coveredHighString = max(from, to) == GuitarFingering.stringCount - 1
            return coveredLowString && coveredHighString && direction == .down
        case let (.upStrum, .strum(from, to, direction)):
            let coveredLowString = min(from, to) == 0
            let coveredHighString = max(from, to) == GuitarFingering.stringCount - 1
            return coveredLowString && coveredHighString && direction == .up
        case let (.mutedStrum(expectedDirection), .strum(from, to, direction)):
            let coveredLowString = min(from, to) == 0
            let coveredHighString = max(from, to) == GuitarFingering.stringCount - 1
            return coveredLowString && coveredHighString && direction == expectedDirection
        case (.rest, _):
            return false
        default:
            return false
        }
    }

    private var hasPlayableChord: Bool {
        guard isConnectedEnsemble else { return true }
        return ChordJudge.matches(
            played: peer.receivedFingering.frets,
            target: currentStrumChord.fingering.frets
        )
    }

    private func syncSharedProgress(_ step: Int) {
        guard isConnectedEnsemble else { return }
        switch mode {
        case .chord:
            strumStepIndex = max(0, step)
            controller.setExternalPosition(songPosition(for: step).bar)
        case .strum:
            if strumStepIndex != step {
                strumStepIndex = max(0, step)
            }
        }
    }
}

private struct DrillHeaderScoreStrip: View {
    let mode: PrototypeMode
    let song: PracticeSong
    let activeBarIndex: Int
    let activeStepIndex: Int

    private let barsPerLine = 4

    var body: some View {
        HStack(spacing: 0) {
            ForEach(visibleBarIndices, id: \.self) { index in
                    HeaderScoreMeasure(
                        mode: mode,
                        chord: song.chords[index],
                        lyric: song.lyric(at: index),
                        steps: song.pick(at: index).steps,
                        isActiveBar: index == activeBarIndex,
                        activeStepIndex: index == activeBarIndex ? activeStepIndex : nil
                    )
            }
        }
        .frame(height: 34)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.gsTextPrimary.opacity(0.92))
                .frame(width: 1)
        }
        .rotationEffect(.degrees(180))
        .clipped()
    }

    private var visibleBarIndices: [Int] {
        guard !song.chords.isEmpty else { return [] }
        let pageStart = (max(activeBarIndex, 0) / barsPerLine) * barsPerLine
        let pageEnd = min(pageStart + barsPerLine, song.chords.count)
        return Array(pageStart..<pageEnd)
    }
}

private struct HeaderScoreMeasure: View {
    let mode: PrototypeMode
    let chord: GuitarChord
    let lyric: String
    let steps: [PickPattern.Step]
    let isActiveBar: Bool
    let activeStepIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            rhythmNotation
                .frame(height: 16, alignment: .bottomLeading)
                .padding(.leading, 30)
                .padding(.trailing, 4)

            Rectangle()
                .fill(Color.gsTextPrimary.opacity(0.92))
                .frame(height: 1)

            Text(lyric)
                .font(.system(size: 8, weight: isActiveBar ? .bold : .medium, design: .rounded))
                .foregroundStyle(isActiveBar ? Color.gsAccent : Color.gsTextPrimary.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 10, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 1)
        }
        .frame(height: 34)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            Text(chord.name)
                .font(.system(
                    size: 12,
                    weight: isActiveBar && mode == .chord ? .heavy : .bold,
                    design: .rounded
                ))
                .foregroundStyle(
                    isActiveBar && mode == .chord
                        ? Color.gsAccent
                        : Color.gsTextPrimary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 28, height: 16, alignment: .leading)
                .padding(.leading, 3)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.gsTextPrimary.opacity(0.92))
                .frame(width: 1)
        }
    }

    private var rhythmNotation: some View {
        HStack(spacing: 1) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                let style = rhythmStyle(for: step, at: index)
                let highlightsStep = mode == .strum && activeStepIndex == index
                Text(symbol(for: step, chord: chord))
                    .font(.system(
                        size: highlightsStep ? style.fontSize + 1 : style.fontSize,
                        weight: highlightsStep ? .heavy : style.weight,
                        design: .rounded
                    ))
                    .foregroundStyle(
                        highlightsStep
                            ? Color.gsAccent
                            : Color.gsTextPrimary.opacity(style.opacity)
                    )
                    .offset(y: style.yOffset)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private struct RhythmStyle {
        let fontSize: CGFloat
        let weight: Font.Weight
        let opacity: Double
        let yOffset: CGFloat
    }

    private func rhythmStyle(for step: PickPattern.Step, at index: Int) -> RhythmStyle {
        if step == .rest {
            return RhythmStyle(fontSize: 8, weight: .bold, opacity: 0.35, yOffset: 0)
        }

        if isStrongBeat(step: step, at: index) {
            return RhythmStyle(fontSize: 11, weight: .heavy, opacity: 0.98, yOffset: -1)
        }

        if isGhostBeat(step: step, at: index) {
            return RhythmStyle(fontSize: 8, weight: .semibold, opacity: 0.48, yOffset: 1)
        }

        if step == .upStrum {
            return RhythmStyle(fontSize: 9, weight: .bold, opacity: 0.72, yOffset: 0)
        }

        return RhythmStyle(fontSize: 9, weight: .bold, opacity: 0.78, yOffset: 0)
    }

    private func isStrongBeat(step: PickPattern.Step, at index: Int) -> Bool {
        guard step == .strum else { return false }

        if steps.count == 16 {
            return index % 4 == 0
        }

        if steps.count == 8 {
            return index == 0 || index == 6
        }

        return index == 0
    }

    private func isGhostBeat(step: PickPattern.Step, at index: Int) -> Bool {
        guard step == .strum else { return false }

        if steps.count == 16 {
            return index % 4 == 2
        }

        if steps.count == 8 {
            return index == 4
        }

        return false
    }

    private func symbol(for step: PickPattern.Step, chord: GuitarChord) -> String {
        switch step {
        case .bass:
            guard let stringIndex = chord.fingering.lowestAudibleString else { return "-" }
            return "\(GuitarFingering.stringCount - stringIndex)"
        case let .pluck(index):
            return "\(GuitarFingering.stringCount - index)"
        case .strum:
            return "∩"
        case .upStrum:
            return "V"
        case .mutedStrum:
            return "X"
        case .rest:
            return "·"
        }
    }
}

private struct StrumDrillGuideOverlay: View {
    let step: PickPattern.Step
    let chord: GuitarChord
    let isPad: Bool

    @Environment(\.stageMetrics) private var stageMetrics

    var body: some View {
        GeometryReader { proxy in
            let band = stringBandFrame(in: proxy.size)
            ZStack {
                switch step {
                case .bass:
                    if let stringIndex = chord.fingering.lowestAudibleString {
                        pluckGuide(stringIndex: stringIndex, in: band, size: proxy.size)
                    }
                case let .pluck(stringIndex):
                    pluckGuide(stringIndex: stringIndex, in: band, size: proxy.size)
                case .strum:
                    strumArrow(from: 0, to: GuitarFingering.stringCount - 1, in: band, size: proxy.size)
                case .upStrum:
                    strumArrow(from: GuitarFingering.stringCount - 1, to: 0, in: band, size: proxy.size)
                case .mutedStrum(let direction):
                    mutedStrumGuide(direction: direction, in: band, size: proxy.size)
                case .rest:
                    EmptyView()
                }
            }
        }
    }

    private func pluckGuide(stringIndex: Int, in band: CGRect, size: CGSize) -> some View {
        let y = stringY(for: stringIndex, in: band)
        let x = size.width * 0.72
        let finger = chord.fingers.indices.contains(stringIndex) ? chord.fingers[stringIndex] : 0

        return HStack(spacing: 8) {
            Text("\(GuitarFingering.stringCount - stringIndex)번 줄")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.gsAccent)
            Text("\(finger)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.gsOnAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.gsAccent))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.gsStageBackground.opacity(0.72)))
        .overlay(Capsule().stroke(Color.gsAccent, lineWidth: 1.5))
        .rotationEffect(.degrees(180))
        .position(x: x, y: y)
    }

    private func strumArrow(from startString: Int, to endString: Int, in band: CGRect, size: CGSize) -> some View {
        let x = size.width * 0.72
        let start = CGPoint(x: x, y: stringY(for: startString, in: band))
        let end = CGPoint(x: x, y: stringY(for: endString, in: band))

        return ZStack {
            Path { path in
                path.move(to: start)
                path.addLine(to: end)

                let arrowLength: CGFloat = 15
                let arrowSpread: CGFloat = 9
                let direction: CGFloat = end.y >= start.y ? 1 : -1
                path.move(to: end)
                path.addLine(to: CGPoint(x: end.x - arrowSpread, y: end.y - direction * arrowLength))
                path.move(to: end)
                path.addLine(to: CGPoint(x: end.x + arrowSpread, y: end.y - direction * arrowLength))
            }
            .stroke(Color.gsAccent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

            Text("\(GuitarFingering.stringCount - startString) → \(GuitarFingering.stringCount - endString)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.gsAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.gsStageBackground.opacity(0.72)))
                .rotationEffect(.degrees(180))
                .position(x: x + 54, y: (start.y + end.y) / 2)
        }
    }

    private func mutedStrumGuide(direction: StrumDirection, in band: CGRect, size: CGSize) -> some View {
        let start = direction == .down ? 0 : GuitarFingering.stringCount - 1
        let end = direction == .down ? GuitarFingering.stringCount - 1 : 0
        let x = size.width * 0.72
        let centerY = (stringY(for: start, in: band) + stringY(for: end, in: band)) / 2

        return ZStack {
            strumArrow(from: start, to: end, in: band, size: size)

            Text("MUTE")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.gsOnAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.gsAccent))
                .rotationEffect(.degrees(180))
                .position(x: x - 54, y: centerY)
        }
    }

    private func stringBandFrame(in size: CGSize) -> CGRect {
        StrumNeckLayout.stringBandFrame(
            in: size,
            isPad: isPad,
            stageScale: stageMetrics.scale
        )
    }

    private func stringY(for stringIndex: Int, in band: CGRect) -> CGFloat {
        let spacing = band.height / CGFloat(GuitarFingering.stringCount)
        let middleOffset = (CGFloat(GuitarFingering.stringCount) - 1) / 2
        return band.midY + (CGFloat(stringIndex) - middleOffset) * spacing
    }
}

#Preview("코드 드릴") {
    PortraitLockedLandscapeStage {
        ChordDrillScreen(
            song: PracticeSongData.songs[0],
            peer: PeerConnectViewModel(
                deviceType: .iPhone,
                service: MockMultipeerService()
            )
        )
            .environmentObject(AppRouter(deviceType: .iPhone))
    }
}
