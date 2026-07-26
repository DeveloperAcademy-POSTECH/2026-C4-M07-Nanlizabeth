import SwiftUI

/// 연주 화면을 벗어나지 않고 근처 디바이스를 찾고 연결하는 빠른 연결 팝오버.
struct PeerQuickConnectPopover: View {
    @ObservedObject var viewModel: PeerConnectViewModel
    var onPeerSelected: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isConnected {
                connectedRow
            } else {
                searchingHeader
                discoveredPeerRows
            }
        }
        .frame(width: InstrumentControlHitRegion.peerPopover.width)
        .padding(.vertical, 8)
        .background {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var discoveredPeerRows: some View {
        if !viewModel.discoveredPeers.isEmpty {
            ForEach(viewModel.discoveredPeers, id: \.self) { peer in
                Button {
                    viewModel.invite(peer)
                    onPeerSelected(peer)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "ipad.and.iphone")
                            .frame(width: 22)
                        Text(peer)
                            .lineLimit(1)
                        Spacer()
                        if case .inviting(let name) = viewModel.flowState, name == peer {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var searchingHeader: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("근처 애플 디바이스를 찾고 있어요!")
                .lineLimit(1)
            Spacer()
        }
        .font(.system(size: 15))
        .foregroundStyle(Color.gsTextSecondary)
        .padding(.horizontal, 20)
        .frame(height: 48)
    }

    private var connectedRow: some View {
        Button {
            if viewModel.isInitiator {
                viewModel.disconnect()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.gsAccent)
                    .frame(width: 22)
                Text(viewModel.connectedPeerName ?? "연결된 디바이스")
                    .lineLimit(1)
                Spacer()
            }
            .font(.system(size: 17))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isInitiator)
    }

}
