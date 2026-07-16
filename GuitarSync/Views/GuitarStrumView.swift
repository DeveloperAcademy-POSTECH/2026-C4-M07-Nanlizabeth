import SwiftUI

struct GuitarStrumView: View {
    @ObservedObject var viewModel: GuitarStrumViewModel

    var stringAssetNames: [String]
    private let stringCenterSpacing: CGFloat = 56

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
    }

    init(
        viewModel: GuitarStrumViewModel,
        stringAssetNames: [String] = Self.defaultStringAssetNames
    ) {
        self.viewModel = viewModel
        self.stringAssetNames = stringAssetNames
    }

    var body: some View {
        GeometryReader { proxy in
            let stringBand = stringBandFrame(in: proxy.size)

            ZStack {
                background
                guitarBody(in: proxy.size)
                strings(in: proxy.size, band: stringBand)

                // The images are visual only. Sound is requested through this transparent input layer.
                StringInputLayerView(
                    onChanged: viewModel.handleInputChanged(location:in:),
                    onEnded: viewModel.handleInputEnded
                )
                .frame(width: stringBand.width, height: stringBand.height)
                .position(x: stringBand.midX, y: stringBand.midY)

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

    private var background: some View {
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

    private func strings(in size: CGSize, band: CGRect) -> some View {
        let stringCount = min(viewModel.layoutConfiguration.stringCount, stringAssetNames.count)

        return ZStack {
            ForEach(0..<stringCount, id: \.self) { stringIndex in
                GuitarStringImageView(
                    assetName: stringAssetNames[stringIndex],
                    stringIndex: stringIndex
                )
                .frame(width: size.width * 1.06, height: stringHeight(for: stringIndex))
                .position(
                    x: size.width / 2,
                    y: stringY(for: stringIndex, stringCount: stringCount, in: band)
                )
            }
        }
    }

    private func soundHoleDiameter(in size: CGSize) -> CGFloat {
        min(size.height * 1.38, 560)
    }

    private func soundHoleCenter(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.36, y: size.height * 0.50)
    }

    private func stringBandFrame(in size: CGSize) -> CGRect {
        let center = soundHoleCenter(in: size)
        let stringCount = CGFloat(viewModel.layoutConfiguration.stringCount)
        let bandHeight = stringCenterSpacing * stringCount

        return CGRect(
            x: 0,
            y: center.y - bandHeight / 2,
            width: size.width,
            height: bandHeight
        )
    }

    private func stringY(for stringIndex: Int, stringCount: Int, in band: CGRect) -> CGFloat {
        let middleOffset = (CGFloat(stringCount) - 1) / 2
        return band.midY + (CGFloat(stringIndex) - middleOffset) * stringCenterSpacing
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
        }
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
    }
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
