import AVKit
import SwiftUI

/// Thin wrapper around SwiftUI's VideoPlayer.
struct PlayerView: View {
    let player: AVPlayer

    var body: some View {
        VideoPlayer(player: player)
            .frame(minHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
