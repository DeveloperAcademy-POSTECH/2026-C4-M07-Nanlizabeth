#if DEBUG
import SwiftUI

/// 디버그 빌드에서만 보이는 오디오 엔진 A/B 토글 버튼.
///
/// 일반 서비스 버튼(LiquidGlass 스타일)과 확실히 구분되도록,
/// 개발 도구 느낌의 점선 테두리 + 모노스페이스 서체로 그린다.
/// 앱을 끄거나 재빌드하지 않고 Native ↔ AudioKit 엔진을 즉시 바꿔 소리를 비교할 수 있다.
struct DebugAudioEngineToggle: View {
    @ObservedObject var viewModel: GuitarStrumViewModel

    var body: some View {
        Button(action: viewModel.toggleAudioEngine) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 12))

                VStack(alignment: .leading, spacing: 1) {
                    Text("DEBUG · 오디오 엔진")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow.opacity(0.85))
                    Text(viewModel.audioEngineKind.displayName)
                        .font(.system(size: 15, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                }

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                    .foregroundStyle(.yellow.opacity(0.7))
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
