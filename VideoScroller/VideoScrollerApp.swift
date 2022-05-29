import SwiftUI
import AVKit
import Combine

@main
struct VideoScrollerApp: App {
    var body: some Scene {
        WindowGroup {
            VideoScroller()
        }
    }
}

struct VideoScroller: View {
    static let videos = [
        "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.jpg",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4"
    ]

    @State private var lastPositionMap: [AnyHashable: TimeInterval] = [:]

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 2) {
                ForEach(Self.videos, id: \.self) { url in
                    VideoView(
                        videoURL: URL(string: url)!,
                        lastPositionMap: $lastPositionMap
                    )
                    .background(Color.black)
                    .padding(10)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    Spacer(minLength: 400)
                }
            }
        }
    }
}

struct VideoView: View {
    @State private var player = AVPlayer()

    @Binding var lastPositionMap: [AnyHashable: TimeInterval]

    private let videoURL: URL
    private var timeStateSubscriber: Any?

    // MARK: - Init

    init(
        videoURL: URL,
        lastPositionMap: Binding<[AnyHashable: TimeInterval]>
    ) {
        self.videoURL = videoURL
        self._lastPositionMap = lastPositionMap

        timeStateSubscriber = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: nil) { [self] time in
                $lastPositionMap.wrappedValue[videoURL] = time.seconds
        }
    }

    var body: some View {
        PlayerView(
            player: $player,
            visible: .constant(true),
            onVideoCompleted: { },
            onVideoError: { }
        )
        .onReceive(playOnReadyPublisher(), perform: { [weak player] asset in
            debugPrint("Video isPlayable: \(asset.isPlayable)")
            player?.replaceCurrentItem(with: .init(asset: asset))
            player?.play()
        })
        .onAppear(perform: {
            // playOnReadyAsynchronously()
        })
        .onDisappear {
            player.pause()
            player.currentItem?.asset.cancelLoading()
        }
    }
}

private extension VideoView {
    /**
     Loads `isPlayable` status asynchronously for smoother scroll:
     */
    func playOnReadyAsynchronously() {
        let keys = [
            #keyPath(AVAsset.duration),
            #keyPath(AVAsset.isPlayable)
        ]

        let asset = AVURLAsset(url: videoURL)
        asset.loadValuesAsynchronously(forKeys: keys) { [weak player] in
            var error: NSError?
            let status = asset.statusOfValue(
                forKey: #keyPath(AVAsset.isPlayable),
                error: &error
            )
            switch status {
            case .loaded:
                DispatchQueue.main.async { [weak player] in
                    guard let player = player else { return }
                    player.replaceCurrentItem(with: .init(asset: asset))

                    if let position = lastPositionMap[videoURL] {
                        player.seek(to: .init(seconds: position, preferredTimescale: asset.duration.timescale))
                    }

                    player.play()
                }
            default:
                break
            }
        }
    }

    func playOnReadyPublisher() -> AnyPublisher<AVURLAsset, Never> {
        let asset = AVURLAsset(url: videoURL)
        return asset
            .publisher(for: \.isPlayable)
            .subscribe(on: DispatchQueue.global(qos: .background))
            .receive(on: RunLoop.main)
            .map({ _ in asset })
            .eraseToAnyPublisher()
    }
}
