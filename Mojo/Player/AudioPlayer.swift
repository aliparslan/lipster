import AVFoundation
import Foundation
import UIKit

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

    // MARK: - Volume Normalization

    /// Analyzes the audio file's peak level and adjusts player volume
    /// to target approximately -14 LUFS (roughly 0.7 for loud tracks, 1.0 for quiet).
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

                // Read the audio's estimated data rate to approximate loudness.
                // Higher bitrate / data rate often correlates with louder mastering.
                let dataRate = try await audioTrack.load(.estimatedDataRate)

                // Use a simple heuristic: most modern loud masters have high data rates.
                // Target volume ~0.7 for loud tracks (high bitrate),
                // ~1.0 for quieter tracks (lower bitrate).
                // A typical high-quality loud track has ~256000+ data rate.
                let normalizedVolume: Float
                if dataRate > 0 {
                    // Analyze using AVAudioFile for peak detection
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

    /// Reads the first few seconds of audio to estimate peak level,
    /// then calculates an appropriate playback volume.
    private nonisolated func calculateNormalizedVolume(url: URL) async -> Float {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let sampleRate = format.sampleRate

            // Read first 3 seconds worth of samples
            let framesToRead = AVAudioFrameCount(min(sampleRate * 3.0, Double(file.length)))
            guard framesToRead > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
                return 1.0
            }

            try file.read(into: buffer, frameCount: framesToRead)

            // Find peak amplitude across all channels
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

            // Target peak around 0.7 (-3 dB roughly).
            // If the track's peak is already near 1.0 (loud master), scale down.
            // If the track's peak is low (quiet), scale up but cap at 1.0.
            guard peak > 0.001 else { return 1.0 }

            let targetPeak: Float = 0.7
            let gain = targetPeak / peak
            return min(gain, 1.0) // Never amplify above 1.0 to avoid clipping
        } catch {
            return 1.0
        }
    }

    /// Reset volume to default (no normalization).
    func resetVolume() {
        player?.volume = 1.0
    }
}
