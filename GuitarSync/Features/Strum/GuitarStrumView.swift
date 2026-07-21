import SwiftUI

struct GuitarStrumView: View {
    @ObservedObject var viewModel: GuitarStrumViewModel

    var stringAssetNames: [String]

    /// iPad는 Figma 하이파이 이미지를 배경으로 깔고, 그 위에 투명 터치 레이어만 얹는다.
    /// iPhone은 기존(갈색) SwiftUI 레이아웃 그대로. 터치·소리 로직은 두 경우 공통.
    var isPad: Bool

    /// 스테이지(도화지→화면) 배율. iPhone·iPad **모두** 넥(줄 밴드)을 화면상 **고정 크기**로
    /// 유지하려고 이 배율로 역보정한다 — 기기 크기가 달라도 넥 두께가 항상 같다.
    @Environment(\.stageMetrics) private var stageMetrics

    private static let defaultStringAssetNames = [
        "guitar_string_6",
        "guitar_string_5",
        "guitar_string_4",
        "guitar_string_3",
        "guitar_string_2",
        "guitar_string_1"
    ]

    init() {
        self.viewModel = GuitarStrumViewModel()
        self.stringAssetNames = Self.defaultStringAssetNames
        self.isPad = false
    }

    init(
        viewModel: GuitarStrumViewModel,
        stringAssetNames: [String] = Self.defaultStringAssetNames,
        isPad: Bool = false
    ) {
        self.viewModel = viewModel
        self.stringAssetNames = stringAssetNames
        self.isPad = isPad
    }

    var body: some View {
        GeometryReader { proxy in
            let stringBand = stringBandFrame(in: proxy.size)

            ZStack {
                instrumentBackground(in: proxy.size)

                // iPhone은 SwiftUI로 기타를 그린다. iPad는 배경 이미지에 기타가 이미 있으니 생략.
                if !isPad {
                    guitarBody(in: proxy.size)
                    strings(in: proxy.size, band: stringBand)
                }

                // 소리는 이 투명 레이어를 통해 요청된다. **손가락을 전부 받는다** — 아르페지오처럼
                // 여러 줄을 동시에 튕기려면 필요하다. 터치 영역은 화면 전체, 줄 매핑은 stringBand.
                MultiTouchLayer { touches in
                    viewModel.handleTouchesChanged(touches, band: stringBand)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                if viewModel.debugOverlayEnabled {
                    debugOverlay
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .clipped()
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.045))
        .onAppear(perform: viewModel.startAudio)
        .onDisappear(perform: viewModel.stopAudio)
    }

    // MARK: - 배경

    @ViewBuilder
    private func instrumentBackground(in size: CGSize) -> some View {
        if isPad { padBackground(in: size) } else { phoneBackground }
    }

    /// Figma 하이파이 이미지를 배경으로 깐다. **줄 밴드(넥)가 화면에서 항상 같은 크기**가 되도록
    /// 이미지를 확대하고, 줄 밴드가 세로 정중앙에 오도록 이미지를 옮긴다. 넘치는 부분은 잘린다.
    private func padBackground(in size: CGSize) -> some View {
        let metrics = padImageMetrics(in: size)
        return ZStack {
            Color(red: 0.02, green: 0.025, blue: 0.032)
            Image("ipadStrumBackground")
                .resizable()
                .scaledToFill()
                .frame(width: metrics.imageWidth, height: metrics.imageHeight)
                .offset(y: metrics.imageOffsetY)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .ignoresSafeArea()
    }

    private var phoneBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.055, blue: 0.025),
                    Color(red: 0.42, green: 0.20, blue: 0.075),
                    Color(red: 0.12, green: 0.065, blue: 0.030)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            Rectangle()
                .fill(Color.black.opacity(0.12))
                .overlay(
                    VStack(spacing: 18) {
                        ForEach(0..<12, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.035))
                                .frame(height: 1)
                        }
                    }
                )
        }
        .ignoresSafeArea()
    }

    // MARK: - iPhone 기타 그림 (배경·사운드홀·넥)

    private func guitarBody(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: soundHoleDiameter(in: size), height: soundHoleDiameter(in: size))
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 8))
                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 30))
                .position(x: soundHoleCenter(in: size).x, y: soundHoleCenter(in: size).y)

            Rectangle()
                .fill(Color(red: 0.08, green: 0.09, blue: 0.10).opacity(0.96))
                .frame(width: max(size.width * 0.32, 260), height: size.height)
                .position(x: size.width * 0.82, y: size.height / 2)

            ForEach([0.69, 0.80, 0.89], id: \.self) { ratio in
                Rectangle()
                    .fill(Color(red: 0.72, green: 0.78, blue: 0.84))
                    .frame(width: 8, height: size.height * 0.68)
                    .position(x: size.width * ratio, y: size.height * 0.50)
            }
        }
    }

    /// iPhone 줄 그림. 줄 간격은 **넥 밴드에서 파생**(band 높이 / 줄 수) → 넥 고정과 항상 일치.
    private func strings(in size: CGSize, band: CGRect) -> some View {
        let count = viewModel.layoutConfiguration.stringCount
        let stringCount = min(count, stringAssetNames.count)
        let spacing = band.height / CGFloat(count)

        return ZStack {
            ForEach(0..<stringCount, id: \.self) { stringIndex in
                GuitarStringImageView(
                    assetName: stringAssetNames[stringIndex],
                    stringIndex: stringIndex
                )
                .frame(width: size.width * 1.06, height: stringHeight(for: stringIndex))
                .position(
                    x: size.width / 2,
                    y: stringY(for: stringIndex, stringCount: stringCount, in: band, spacing: spacing)
                )
            }
        }
    }

    private func soundHoleDiameter(in size: CGSize) -> CGFloat {
        min(size.height * 1.38, 560)
    }

    private func soundHoleCenter(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.36, y: size.height * StrumNeck.verticalCenter)
    }

    // MARK: - iPad 이미지 크기·오프셋 (넥 고정 + 정중앙)

    /// iPad 배경 이미지의 크기·오프셋·밴드 높이(캔버스 좌표). **넥이 화면상 고정 크기**가 되도록
    /// 스테이지 배율로 역산하고, 이미지 속 줄 중심이 세로 정중앙에 오게 옮긴다.
    private func padImageMetrics(in size: CGSize)
        -> (imageWidth: CGFloat, imageHeight: CGFloat, bandHeight: CGFloat, imageOffsetY: CGFloat) {
        let scale = max(stageMetrics.scale, 0.01)
        let bandHeight = StrumNeck.spanPointsPad / scale
        let imageHeight = bandHeight / StrumNeck.imageBandRatio
        let imageWidth = imageHeight * StrumNeck.imageAspect
        // 이미지 속 줄 중심(imageBandCenter)이 화면의 verticalCenter에 오도록 이미지를 옮긴다.
        let imageOffsetY = size.height * (StrumNeck.verticalCenter - 0.5)
            + (0.5 - StrumNeck.imageBandCenter) * imageHeight
        return (imageWidth, imageHeight, bandHeight, imageOffsetY)
    }

    // MARK: - 줄 밴드(터치 영역). 넥 고정 + 세로 정중앙. iPhone·iPad 공통 원리.

    private func stringBandFrame(in size: CGSize) -> CGRect {
        let centerY = size.height * StrumNeck.verticalCenter
        let scale = max(stageMetrics.scale, 0.01)

        let bandHeight: CGFloat
        if isPad {
            bandHeight = padImageMetrics(in: size).bandHeight
        } else {
            // iPhone도 넥 고정: 배율 역보정. 작은 기기에서 캔버스를 넘지 않게 클램프.
            bandHeight = min(StrumNeck.spanPointsPhone / scale, size.height)
        }

        return CGRect(
            x: 0,
            y: centerY - bandHeight / 2,
            width: size.width,
            height: bandHeight
        )
    }

    private func stringY(for stringIndex: Int, stringCount: Int, in band: CGRect, spacing: CGFloat) -> CGFloat {
        let middleOffset = (CGFloat(stringCount) - 1) / 2
        return band.midY + (CGFloat(stringIndex) - middleOffset) * spacing
    }

    private func stringHeight(for stringIndex: Int) -> CGFloat {
        switch stringIndex {
        case 0: return 8
        case 1: return 7
        case 2: return 6
        default: return 5
        }
    }

    private var debugOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("axis: \(viewModel.debugState.axis.rawValue)")
            Text("axisValue: \(Int(viewModel.debugState.axisValue))")
            Text("stringIndex: \(viewModel.debugState.stringIndex.map(String.init) ?? "-")")
            Text("raw: \(viewModel.debugState.rawDirection?.rawValue ?? "-")")
            Text("mapped: \(viewModel.debugState.direction?.displayName ?? "-")")
            Text("reverse: \(viewModel.debugState.reverseStringMapping ? "true" : "false")")
            Text("fingers: \(viewModel.debugState.activeTouchCount)")
        }
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 넥(줄 밴드) 튜닝 값 — iPhone·iPad 공통 개념

/// 넥(6줄 스팬)을 **화면에서 항상 같은 크기**로 고정하고, 세로 정중앙에 둔다.
/// 기기 크기가 달라도 넥 두께가 일정하고, 대신 (iPad는) 이미지 확대 정도가 달라진다.
private enum StrumNeck {
    /// 넥 세로 중심 위치 (화면 높이 대비). 0.5 = 정중앙. 위로 올리려면 값을 줄인다.
    static let verticalCenter: CGFloat = 0.5

    /// iPad 넥 스팬(화면 고정 포인트). 320pt ≈ 61mm (264ppi). 실제 기타 현 스팬대.
    static let spanPointsPad: CGFloat = 320
    /// iPhone 넥 스팬(화면 고정 포인트). 336pt = 기존 값(iPhone 16 Pro 기준) 유지.
    static let spanPointsPhone: CGFloat = 336

    /// iPad 배경 이미지 가로세로비 (측정 5464×4096).
    static let imageAspect: CGFloat = 5464.0 / 4096.0
    /// iPad 이미지 안 6줄의 세로 중심 (이미지 높이 대비, 픽셀 측정값).
    static let imageBandCenter: CGFloat = 0.499
    /// iPad 이미지 안 6줄이 퍼진 전체 높이 (이미지 높이 대비, 측정 span 0.260 × 6/5).
    static let imageBandRatio: CGFloat = 0.312
}

#Preview("Strum Axis Y") {
    PortraitLockedLandscapeStage {
        GuitarStrumView(
            viewModel: GuitarStrumViewModel(
                layoutConfiguration: StrumLayoutConfiguration(
                    strumAxis: .y,
                    reverseStringMapping: false
                ),
                directionMapping: StrumDirectionMapping(forwardIsDown: true),
                debugOverlayEnabled: true
            )
        )
    }
}

#Preview("Strum Axis X Reversed") {
    PortraitLockedLandscapeStage {
        GuitarStrumView(
            viewModel: GuitarStrumViewModel(
                layoutConfiguration: StrumLayoutConfiguration(
                    strumAxis: .x,
                    reverseStringMapping: true
                ),
                directionMapping: StrumDirectionMapping(forwardIsDown: false),
                debugOverlayEnabled: true
            )
        )
    }
}

#Preview("iPad Strum (Figma 배경)") {
    GuitarStrumView(viewModel: GuitarStrumViewModel(), isPad: true)
        .frame(width: 1366, height: 1024)
}
