import AVFoundation
import SwiftUI

struct MutedLoopingVideoView: View {
    let resourceName: String
    let resourceExtension: String

    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        PlayerLayerRepresentable(player: player)
            .onAppear {
                preparePlayerIfNeeded()
                player?.play()
            }
            .onDisappear {
                player?.pause()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    player?.play()
                } else {
                    player?.pause()
                }
            }
            .accessibilityHidden(true)
    }

    private func preparePlayerIfNeeded() {
        guard player == nil,
              let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
        else {
            return
        }

        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        queuePlayer.preventsDisplaySleepDuringVideoPlayback = false
        queuePlayer.actionAtItemEnd = .none

        let templateItem = AVPlayerItem(url: url)
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: templateItem)

        player = queuePlayer
        looper = playerLooper
    }
}

private struct PlayerLayerRepresentable: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
