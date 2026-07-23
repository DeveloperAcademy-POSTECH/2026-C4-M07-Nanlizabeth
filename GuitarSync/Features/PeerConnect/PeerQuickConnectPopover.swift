import SwiftUI

/// 연주 화면을 벗어나지 않고 근처 기기를 찾고 연결하는 빠른 연결 팝오버.
struct PeerQuickConnectPopover: View {
    @ObservedObject var viewModel: PeerConnectViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isConnected {
                connectedRow
            } else if viewModel.isInitiator {
                discoveredPeerRows
            } else {
                waitingRow
            }

            Divider()
                .overlay(Color.white.opacity(0.16))
                .padding(.horizontal, 16)

            searchingRow
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
        if viewModel.discoveredPeers.isEmpty {
            Text("근처 iPad를 찾고 있어요")
                .font(.system(size: 15))
                .foregroundStyle(Color.gsTextSecondary)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .padding(.horizontal, 20)
        } else {
            ForEach(viewModel.discoveredPeers, id: \.self) { peer in
                Button {
                    viewModel.invite(peer)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "ipad")
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
                Text(viewModel.connectedPeerName ?? "연결된 기기")
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

    private var waitingRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "iphone")
                .frame(width: 22)
            Text("iPhone의 연결을 기다리는 중")
            Spacer()
        }
        .font(.system(size: 15))
        .foregroundStyle(Color.gsTextSecondary)
        .padding(.horizontal, 20)
        .frame(height: 48)
    }

    private var searchingRow: some View {
        HStack(spacing: 10) {
            if !viewModel.isConnected {
                ProgressView()
                    .controlSize(.small)
            }
            Text(viewModel.isConnected ? "연결됨" : "Searching for iPad…")
                .lineLimit(1)
            Spacer()
        }
        .font(.system(size: 15))
        .foregroundStyle(Color.gsTextSecondary)
        .padding(.horizontal, 20)
        .frame(height: 44)
    }
}
