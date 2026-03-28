import ActivityKit
import Foundation
import Observation

enum RepeatMode: Int {
    case off = 0
    case all = 1
    case one = 2

    var next: RepeatMode {
        RepeatMode(rawValue: (rawValue + 1) % 3) ?? .off
    }

    var systemImage: String {
        switch self {
        case .off: "repeat"
        case .all: "repeat"
        case .one: "repeat.1"
        }
    }
}

enum QueueInsertPosition {
    case next      // play after current song
    case last      // add to end of queue
}

@MainActor
@Observable
final class AppState {
    var currentSong: Song?
    var isPlaying: Bool = false

    // The original unshuffled queue and the active (possibly shuffled) queue
    private var originalQueue: [Song] = []
    var queue: [Song] = []
    var queueIndex: Int = 0

    // Playback history for going back
    var history: [Song] = []

    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var shuffleEnabled: Bool = false {
        didSet { didToggleShuffle() }
    }
    var repeatMode: RepeatMode = .off

    // Volume normalization
    var volumeNormalizationEnabled: Bool = false

    // Color extraction
    var albumColors: AlbumColors = .placeholder

    let audioPlayer = AudioPlayer()
    let databaseManager = DatabaseManager()
    let nowPlayingManager = NowPlayingManager()
    let liveActivityManager = LiveActivityManager()

    init() {
        setupCallbacks()
    }

    private func setupCallbacks() {
        audioPlayer.onTimeUpdate = { [weak self] currentTime, duration in
            guard let self else { return }
            self.currentTime = currentTime
            self.duration = duration
        }

        audioPlayer.onSongFinished = { [weak self] in
            guard let self else { return }
            switch self.repeatMode {
            case .one:
                if let song = self.currentSong {
                    self.play(song: song)
                }
            case .all:
                self.skipNext()
            case .off:
                if self.queueIndex < self.queue.count - 1 {
                    self.skipNext()
                } else {
                    // End of queue — stop playback
                    self.isPlaying = false
                    self.audioPlayer.pause()
                    self.liveActivityManager.end()
                }
            }
        }

        nowPlayingManager.onPlay = { [weak self] in
            self?.resume()
        }
        nowPlayingManager.onPause = { [weak self] in
            self?.pause()
        }
        nowPlayingManager.onNextTrack = { [weak self] in
            self?.skipNext()
        }
        nowPlayingManager.onPreviousTrack = { [weak self] in
            self?.skipPrevious()
        }
        nowPlayingManager.onSeek = { [weak self] time in
            self?.audioPlayer.seek(to: time)
            self?.currentTime = time
        }
    }

    // MARK: - Playback

    func play(song: Song, queue: [Song]? = nil) {
        // Push current song to history
        if let current = currentSong {
            history.append(current)
            if history.count > 200 { history.removeFirst() }
        }

        currentSong = song
        isPlaying = true

        if let queue {
            originalQueue = queue
            if shuffleEnabled {
                // Fisher-Yates shuffle, keeping tapped song at front
                self.queue = fisherYatesShuffle(queue, startingWith: song)
                self.queueIndex = 0
            } else {
                self.queue = queue
                self.queueIndex = queue.firstIndex(of: song) ?? 0
            }
        }

        audioPlayer.play(song: song)

        // Apply volume normalization if enabled
        if volumeNormalizationEnabled {
            audioPlayer.applyVolumeNormalization(for: song)
        } else {
            audioPlayer.resetVolume()
        }

        // Preload next track for gapless
        preloadNextTrack()

        // Extract colors from album art
        updateAlbumColors(for: song)

        let songDuration = Double(song.durationMs) / 1000.0
        nowPlayingManager.update(song: song, isPlaying: true, currentTime: 0, duration: songDuration)

        // Update Live Activity
        liveActivityManager.update(song: song, isPlaying: true)
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        audioPlayer.pause()
        isPlaying = false
        if let song = currentSong {
            nowPlayingManager.update(song: song, isPlaying: false, currentTime: currentTime, duration: duration)
            liveActivityManager.update(song: song, isPlaying: false)
        }
    }

    func resume() {
        audioPlayer.resume()
        isPlaying = true
        if let song = currentSong {
            nowPlayingManager.update(song: song, isPlaying: true, currentTime: currentTime, duration: duration)
            liveActivityManager.update(song: song, isPlaying: true)
        }
    }

    func skipNext() {
        guard !queue.isEmpty else { return }
        queueIndex = (queueIndex + 1) % queue.count
        let song = queue[queueIndex]
        play(song: song)
    }

    func skipPrevious() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            audioPlayer.seek(to: 0)
            currentTime = 0
            return
        }
        queueIndex = (queueIndex - 1 + queue.count) % queue.count
        let song = queue[queueIndex]
        play(song: song)
    }

    // MARK: - Queue Management

    func addToQueue(_ song: Song, position: QueueInsertPosition) {
        switch position {
        case .next:
            queue.insert(song, at: min(queueIndex + 1, queue.count))
        case .last:
            queue.append(song)
        }
    }

    func addToQueue(_ songs: [Song], position: QueueInsertPosition) {
        switch position {
        case .next:
            let insertAt = min(queueIndex + 1, queue.count)
            queue.insert(contentsOf: songs, at: insertAt)
        case .last:
            queue.append(contentsOf: songs)
        }
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0, index < queue.count, index != queueIndex else { return }
        queue.remove(at: index)
        if index < queueIndex {
            queueIndex -= 1
        }
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        let currentSong = queue[queueIndex]
        queue.move(fromOffsets: source, toOffset: destination)
        // Re-find the current song's position after the move
        if let newIndex = queue.firstIndex(of: currentSong) {
            queueIndex = newIndex
        }
    }

    /// Songs remaining after the current song
    var upNext: [Song] {
        guard !queue.isEmpty, queueIndex < queue.count else { return [] }
        let remaining = Array(queue.suffix(from: queueIndex + 1))
        return remaining
    }

    // MARK: - True Shuffle (Fisher-Yates)

    private func fisherYatesShuffle(_ songs: [Song], startingWith first: Song) -> [Song] {
        var shuffled = songs.filter { $0 != first }
        // Fisher-Yates: iterate from the end, swap each with a random earlier element
        for i in stride(from: shuffled.count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i)
            shuffled.swapAt(i, j)
        }
        // Put the starting song at position 0
        shuffled.insert(first, at: 0)
        return shuffled
    }

    private func didToggleShuffle() {
        guard let current = currentSong else { return }
        if shuffleEnabled {
            queue = fisherYatesShuffle(originalQueue, startingWith: current)
            queueIndex = 0
        } else {
            queue = originalQueue
            queueIndex = originalQueue.firstIndex(of: current) ?? 0
        }
    }

    // MARK: - Gapless Playback

    private func preloadNextTrack() {
        guard !queue.isEmpty else { return }
        let nextIndex = (queueIndex + 1) % queue.count
        guard nextIndex != queueIndex else { return }
        let nextSong = queue[nextIndex]
        audioPlayer.preload(song: nextSong)
    }

    // MARK: - Color Extraction

    private func updateAlbumColors(for song: Song) {
        if let image = song.coverArtImage {
            albumColors = ColorExtractor.shared.extract(from: image, cacheKey: song.album ?? song.spotifyId)
        } else {
            albumColors = .placeholder
        }
    }
}
