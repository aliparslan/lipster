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

    var isActive: Bool {
        self != .off
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

    // Guard to prevent didSet from firing during play(song:queue:)
    private var suppressShuffleDidSet = false

    var shuffleEnabled: Bool = false {
        didSet {
            if !suppressShuffleDidSet {
                didToggleShuffle()
            }
        }
    }
    var repeatMode: RepeatMode = .off

    // Volume normalization
    var volumeNormalizationEnabled: Bool = false

    // Sleep timer
    var sleepTimerMinutes: Int? = nil
    var sleepTimerEndDate: Date? = nil
    private var sleepTimerTask: Task<Void, Never>? = nil

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
            self.handleSongFinished()
        }

        audioPlayer.onPlaybackInterrupted = { [weak self] in
            guard let self, let song = self.currentSong else { return }
            self.isPlaying = false
            self.nowPlayingManager.update(song: song, isPlaying: false, currentTime: self.currentTime, duration: self.duration)
            self.liveActivityManager.update(song: song, isPlaying: false)
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

    // MARK: - Song Finished Handler

    private func handleSongFinished() {
        switch repeatMode {
        case .one:
            if let song = currentSong {
                audioPlayer.seekToBeginning()
                let songDuration = Double(song.durationMs) / 1000.0
                nowPlayingManager.update(song: song, isPlaying: true, currentTime: 0, duration: songDuration)
            }
        case .all:
            advanceToNext()
        case .off:
            if queueIndex < queue.count - 1 {
                advanceToNext()
            } else {
                // End of queue — stop playback
                isPlaying = false
                audioPlayer.pause()
                liveActivityManager.end()
            }
        }
    }

    /// Advance to the next song using gapless playback when possible.
    private func advanceToNext() {
        guard !queue.isEmpty else { return }
        let nextIndex = queueIndex + 1
        let wrappedIndex = nextIndex < queue.count ? nextIndex : 0
        let song = queue[wrappedIndex]

        // Push current to history
        if let current = currentSong {
            history.append(current)
            if history.count > 200 { history.removeFirst() }
        }

        queueIndex = wrappedIndex
        currentSong = song
        isPlaying = true

        // Try gapless advance; fall back to regular play
        if audioPlayer.advanceToPreloaded() {
            // Gapless succeeded — just update metadata
        } else {
            audioPlayer.play(song: song)
        }

        if volumeNormalizationEnabled {
            audioPlayer.applyVolumeNormalization(for: song)
        } else {
            audioPlayer.resetVolume()
        }

        preloadNextTrack()
        updateAlbumColors(for: song)

        let songDuration = Double(song.durationMs) / 1000.0
        nowPlayingManager.update(song: song, isPlaying: true, currentTime: 0, duration: songDuration)
        liveActivityManager.update(song: song, isPlaying: true)
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
                self.queue = fisherYatesShuffle(queue, startingWith: song)
                self.queueIndex = 0
            } else {
                self.queue = queue
                self.queueIndex = queue.firstIndex(of: song) ?? 0
            }
        }

        audioPlayer.play(song: song)

        if volumeNormalizationEnabled {
            audioPlayer.applyVolumeNormalization(for: song)
        } else {
            audioPlayer.resetVolume()
        }

        preloadNextTrack()
        updateAlbumColors(for: song)

        let songDuration = Double(song.durationMs) / 1000.0
        nowPlayingManager.update(song: song, isPlaying: true, currentTime: 0, duration: songDuration)
        liveActivityManager.update(song: song, isPlaying: true)
    }

    /// Play a specific index in the current queue (for queue tap interactions).
    func playAtIndex(_ index: Int) {
        guard index >= 0, index < queue.count else { return }
        queueIndex = index
        play(song: queue[index])
    }

    /// Play with shuffle enabled, avoiding the double-shuffle bug.
    func playShuffled(song: Song, queue: [Song]) {
        suppressShuffleDidSet = true
        shuffleEnabled = true
        suppressShuffleDidSet = false
        play(song: song, queue: queue)
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
        // Bug #3 fix: don't wrap when repeat is off
        if repeatMode == .off && queueIndex >= queue.count - 1 {
            return
        }
        let nextIndex = (queueIndex + 1) % queue.count
        queueIndex = nextIndex
        play(song: queue[nextIndex])
    }

    func skipPrevious() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            audioPlayer.seek(to: 0)
            currentTime = 0
            return
        }
        queueIndex = (queueIndex - 1 + queue.count) % queue.count
        play(song: queue[queueIndex])
    }

    // MARK: - Queue Management

    func addToQueue(_ song: Song, position: QueueInsertPosition) {
        if queue.isEmpty && currentSong == nil {
            // Auto-play if nothing is playing
            play(song: song, queue: [song])
            return
        }
        switch position {
        case .next:
            queue.insert(song, at: min(queueIndex + 1, queue.count))
        case .last:
            queue.append(song)
        }
    }

    func addToQueue(_ songs: [Song], position: QueueInsertPosition) {
        guard !songs.isEmpty else { return }
        if queue.isEmpty && currentSong == nil {
            play(song: songs[0], queue: songs)
            return
        }
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
        // Ensure queueIndex stays valid
        if !queue.isEmpty {
            queueIndex = min(queueIndex, queue.count - 1)
        }
    }

    func moveInQueue(from source: IndexSet, to destination: Int) {
        let currentSong = queue[queueIndex]
        queue.move(fromOffsets: source, toOffset: destination)
        if let newIndex = queue.firstIndex(of: currentSong) {
            queueIndex = newIndex
        }
    }

    /// Songs remaining after the current song
    var upNext: [Song] {
        guard !queue.isEmpty, queueIndex >= 0, queueIndex < queue.count else { return [] }
        let startIndex = queueIndex + 1
        guard startIndex < queue.count else { return [] }
        return Array(queue[startIndex...])
    }

    // MARK: - True Shuffle (Fisher-Yates)

    private func fisherYatesShuffle(_ songs: [Song], startingWith first: Song) -> [Song] {
        var shuffled = songs.filter { $0 != first }
        for i in stride(from: shuffled.count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i)
            shuffled.swapAt(i, j)
        }
        shuffled.insert(first, at: 0)
        return shuffled
    }

    private func didToggleShuffle() {
        guard let current = currentSong, !originalQueue.isEmpty else { return }
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
        let nextIndex = queueIndex + 1
        // Only preload if there's actually a next track
        guard nextIndex < queue.count || repeatMode == .all else { return }
        let wrappedIndex = nextIndex % queue.count
        guard wrappedIndex != queueIndex else { return }
        audioPlayer.preload(song: queue[wrappedIndex])
    }

    // MARK: - Sleep Timer

    func setSleepTimer(minutes: Int) {
        sleepTimerTask?.cancel()
        sleepTimerMinutes = minutes
        sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.pause()
                self?.sleepTimerMinutes = nil
                self?.sleepTimerEndDate = nil
            }
        }
    }

    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerMinutes = nil
        sleepTimerEndDate = nil
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
