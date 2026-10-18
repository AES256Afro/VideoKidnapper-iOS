import AVFoundation
import AVKit
import SwiftUI

struct TrimView: View {
    @EnvironmentObject var store: VideoProjectStore
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 16) {
            if let player {
                PlayerView(player: player)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("In")
                        .frame(width: 36, alignment: .leading)
                    Slider(value: $store.trimStart, in: 0...max(store.trimEnd, 0.01))
                    Text(formatTime(store.trimStart))
                        .font(.caption.monospacedDigit())
                        .frame(width: 56, alignment: .trailing)
                }
                HStack {
                    Text("Out")
                        .frame(width: 36, alignment: .leading)
                    Slider(value: $store.trimEnd, in: min(store.trimStart, store.duration)...store.duration)
                    Text(formatTime(store.trimEnd))
                        .font(.caption.monospacedDigit())
                        .frame(width: 56, alignment: .trailing)
                }
                Text("Clip length: \(formatTime(store.trimEnd - store.trimStart)) of \(formatTime(store.duration))")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button("Preview from In point") {
                    player?.seek(to: CMTime(seconds: store.trimStart, preferredTimescale: 600))
                    player?.play()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Spacer()
        }
        .onAppear {
            if player == nil, let url = store.sourceURL {
                player = AVPlayer(url: url)
            }
        }
        .onChange(of: store.trimStart) { _, value in
            player?.seek(to: CMTime(seconds: value, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        .onDisappear {
            player?.pause()
        }
    }
}
