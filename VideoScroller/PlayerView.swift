import Foundation
import UIKit
import AVKit
import SwiftUI
import Combine

typealias VoidClosure = () -> Void

class PlayerUIView: UIView {
    // MARK: Class Property
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    // MARK: - Helpers
    var playerLayer: AVPlayerLayer? {
        layer as? AVPlayerLayer
    }

    var player: AVPlayer? {
        get {
            return playerLayer?.player
        }
        set {
            playerLayer?.player = newValue
        }
    }
}

struct PlayerView: UIViewRepresentable {
    @Binding var player: AVPlayer
    @Binding var visible: Bool

    let onVideoCompleted: VoidClosure
    let onVideoError: VoidClosure

    var videoBackground: UIColor = .clear
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    // MARK: - UIViewControllerRepresentable

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView()
    }

    func updateUIView(_ uiView: PlayerUIView, context: UIViewRepresentableContext<PlayerView>) {
        uiView.playerLayer?.videoGravity = videoGravity
        uiView.playerLayer?.player = visible ? player : nil
        uiView.backgroundColor = videoBackground
    }

    // MARK: -

    func makeCoordinator() -> PlayerView.Coordinator {
        Coordinator(self, onVideoCompleted: onVideoCompleted, onVideoError: onVideoError)
    }

    class Coordinator: NSObject {
        let parent: PlayerView
        let onVideoCompleted: VoidClosure

        private var cancellables = Set<AnyCancellable>()

        init(
            _ parent: PlayerView,
            onVideoCompleted: @escaping VoidClosure,
            onVideoError: @escaping VoidClosure
        ) {
            self.parent = parent
            self.onVideoCompleted = onVideoCompleted
            super.init()

            let currentItem = parent.player
                .publisher(for: \.currentItem)
                .compactMap({ $0 })

            currentItem
                .flatMap({ NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: $0) })
                .share()
                .sink(receiveValue: { [onVideoCompleted] _ in
                    onVideoCompleted()
                })
                .store(in: &cancellables)

            currentItem
                .flatMap({ $0.publisher(for: \.status) })
                .share()
                .filter({ $0 == .failed })
                .sink(receiveValue: { [onVideoError] _ in
                    onVideoError()
                })
                .store(in: &cancellables)
        }
    }
}
