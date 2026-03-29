import AVFoundation
import Foundation
import UIKit

@MainActor
final class AudioPlayer: NSObject {
    private var player: AVQueuePlayer?
    private var timeObserver: Any?
    private var preloadedItem: AVPlayerItem?
    private var preloadedSong: Song?

    var currentSong: Song?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0

    var onTimeUpdate: ((TimeInterval, TimeInterval) -> Void)?
    var onSongFinished: (() -> Void)?
    var onPlaybackInterrupted: (() -> Void)?

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
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification, object: nil
        )
    }

    /// User-initiated play: creates a new player instance.
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

    /// Attempt to advance to the preloaded item for gapless playback.
    /// Returns true if gapless advance succeeded, false if caller should use play(song:).
    func advanceToPreloaded() -> Bool {
        guard let player, let preloadedItem else { return false }

        // AVQueuePlayer auto-advances, so the preloaded item may already be currentItem
        let alreadyAdvanced = player.currentItem == preloadedItem
        let stillQueued = player.items().contains(preloadedItem)

        guard alreadyAdvanced || stillQueued else { return false }

        // Remove observer from old item
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        currentSong = preloadedSong

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: preloadedItem
        )

        currentTime = 0
        duration = 0
        self.preloadedItem = nil
        self.preloadedSong = nil
        isPlaying = true
        return true
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
        preloadedSong = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func seekToBeginning() {
        let start = CMTime(seconds: 0, preferredTimescale: 600)
        player?.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
        player?.play()
        currentTime = 0
        isPlaying = true
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    /// Preload the next song for gapless playback.
    func preload(song: Song) {
        guard let fileURL = song.fileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let item = AVPlayerItem(url: fileURL)
        preloadedItem = item
        preloadedSong = song

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
        // Bug #7 fix: notification may fire off main thread
        Task { @MainActor [weak self] in
            self?.onSongFinished?()
        }
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if type == .began {
                self.isPlaying = false
                self.onPlaybackInterrupted?()
            } else if type == .ended {
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.player?.play()
                        self.isPlaying = true
                    }
                }
            }
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if reason == .oldDeviceUnavailable {
                // Headphones unplugged — pause
                self.player?.pause()
                self.isPlaying = false
                self.onPlaybackInterrupted?()
            }
        }
    }

    // MARK: - Volume Normalization

    func applyVolumeNormalization(for song: Song) {
        guard let fileURL = song.fileURL else {
            player?.volume = 1.0
            return
        }

        let asset = AVAsset(url: fileURL)
        Task {
            do {
                guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                    await MainActor.run { self.player?.volume = 1.0 }
                    return
                }

                let dataRate = try await audioTrack.load(.estimatedDataRate)

                let normalizedVolume: Float
                if dataRate > 0 {
                    normalizedVolume = await self.calculateNormalizedVolume(url: fileURL)
                } else {
                    normalizedVolume = 1.0
                }

                await MainActor.run {
                    self.player?.volume = normalizedVolume
                }
            } catch {
                await MainActor.run {
                    self.player?.volume = 1.0
                }
            }
        }
    }

    private nonisolated func calculateNormalizedVolume(url: URL) async -> Float {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let sampleRate = format.sampleRate

            let framesToRead = AVAudioFrameCount(min(sampleRate * 3.0, Double(file.length)))
            guard framesToRead > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
                return 1.0
            }

            try file.read(into: buffer, frameCount: framesToRead)

            var peak: Float = 0.0
            if let floatData = buffer.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    for frame in 0..<Int(buffer.frameLength) {
                        let sample = abs(floatData[channel][frame])
                        if sample > peak {
                            peak = sample
                        }
                    }
                }
            }

            guard peak > 0.001 else { return 1.0 }

            let targetPeak: Float = 0.7
            let gain = targetPeak / peak
            return min(gain, 1.0)
        } catch {
            return 1.0
        }
    }

    func resetVolume() {
        player?.volume = 1.0
    }
}
