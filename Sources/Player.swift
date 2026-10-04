import AVFoundation
import MediaPlayer

@MainActor
final class Player: ObservableObject {
    @Published var current: Track?
    @Published var isPlaying = false
    private let avp = AVPlayer()
    private var queue: [Track] = []
    private var index = 0

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }; return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }; return .success
        }
        cc.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in await self?.next() }; return .success
        }
        cc.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in await self?.previous() }; return .success
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.next() }
        }
    }

    func play(_ t: Track, in list: [Track]) async {
        queue = list
        index = list.firstIndex(where: { $0.id == t.id }) ?? 0
        await start(t)
    }

    private func start(_ t: Track) async {
        current = t
        do {
            let url = try await SC.streamURL(for: t)
            guard current?.id == t.id else { return }
            avp.replaceCurrentItem(with: AVPlayerItem(url: url))
            resume()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                MPMediaItemPropertyTitle: t.title,
                MPMediaItemPropertyArtist: t.user.username,
            ]
        } catch {
            isPlaying = false
            print("play error:", error)
        }
    }

    func next() async {
        guard index + 1 < queue.count else { return }
        index += 1
        await start(queue[index])
    }

    func previous() async {
        guard index > 0 else { return }
        index -= 1
        await start(queue[index])
    }

    func resume() { avp.play(); isPlaying = true }
    func pause() { avp.pause(); isPlaying = false }
    func toggle() { isPlaying ? pause() : resume() }
}
