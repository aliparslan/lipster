import AVFoundation
import Foundation

@MainActor
final class AudioPlayer: NSObject {
    private var player: AVQueuePlayer?
    private var timeObserver: Any?
    private var preloadedItem: AVPlayerItem?

    var currentSong: Song?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0

    var onTimeUpdate: ((TimeInterval, TimeInterval) -> Void)?
    var onSongFinished: (() -> Void)?

    override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[AudioPlayer] Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func play(song: Song) {
        stop()
        currentSong = song

        guard let fileURL = song.fileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[AudioPlayer] File not found: \(song.filePath)")
            return
        }

        let playerItem = AVPlayerItem(url: fileURL)
        player = AVQueuePlayer(playerItem: playerItem)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        addTimeObserver()
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        player?.play()
        isPlaying = true
    }

    func stop() {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        player?.pause()
        player?.removeAllItems()
        player = nil
        preloadedItem = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    /// Preload the next song for gapless playback.
    /// AVQueuePlayer will automatically transition when the current item finishes.
    func preload(song: Song) {
        guard let fileURL = song.fileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let item = AVPlayerItem(url: fileURL)
        preloadedItem = item

        // Only insert if the player exists and doesn't already have it queued
        if let player, player.canInsert(item, after: player.currentItem) {
            player.insert(item, after: player.currentItem)
        }
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = time.seconds
                if let item = self.player?.currentItem {
                    let dur = item.duration.seconds
                    if dur.isFinite {
                        self.duration = dur
                    }
                }
                self.onTimeUpdate?(self.currentTime, self.duration)
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    @objc private func playerItemDidFinish(_ notification: Notification) {
        onSongFinished?()
    }
}
