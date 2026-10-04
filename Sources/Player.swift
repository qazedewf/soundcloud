import AVFoundation
import MediaPlayer

@MainActor
final class Player: ObservableObject {
    @Published var current: Track?
    @Published var isPlaying = false
    private let avp = AVPlayer()

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
    }

    func play(_ t: Track) async {
        current = t
        do {
            let url = try await SC.streamURL(for: t)
            avp.replaceCurrentItem(with: AVPlayerItem(url: url))
            resume()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                MPMediaItemPropertyTitle: t.title,
                MPMediaItemPropertyArtist: t.user.username,
            ]
        } catch {
            print("play error:", error)
        }
    }

    func resume() { avp.play(); isPlaying = true }
    func pause() { avp.pause(); isPlaying = false }
    func toggle() { isPlaying ? pause() : resume() }
}
