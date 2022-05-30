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
        "https://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4",
        "https://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_2mb.mp4",
        "https://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_5mb.mp4",
        "https://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_10mb.mp4",
        "https://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_20mb.mp4",
        "https://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_30mb.mp4",
        "https://www.sample-videos.com/video123/mp4/480/big_buck_bunny_480p_1mb.mp4",
        "https://www.sample-videos.com/video123/mp4/480/big_buck_bunny_480p_2mb.mp4",
        "https://www.sample-videos.com/video123/mp4/480/big_buck_bunny_480p_5mb.mp4",
        "https://www.sample-videos.com/video123/mp4/480/big_buck_bunny_480p_10mb.mp4"
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
    @State private var isViewDisplayed = false

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
        /*
        .onReceive(playOnReadyPublisher(), perform: { [weak player] asset in
            guard isViewDisplayed else { debugPrint("view no longer visible"); return }
            player?.replaceCurrentItem(with: .init(asset: asset))
            player?.play()
        })
         */
        .onAppear(perform: {
            isViewDisplayed = true
            playOnReadyAsynchronously()
        })
        .onDisappear {
            isViewDisplayed = false
            player.pause()
            player.currentItem?.asset.cancelLoading()
        }
        .onTapGesture {
            player.seek(to: .zero)
            player.play()
        }
    }
}

private extension VideoView {
    /**
     Loads `isPlayable` status asynchronously for smoother scroll:
     */
    func playOnReadyAsynchronously() {
        let keys = [
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
                    guard isViewDisplayed else { debugPrint("view no longer visible"); return }
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
