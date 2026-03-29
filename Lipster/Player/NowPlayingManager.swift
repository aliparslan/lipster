import Foundation
import MediaPlayer
import UIKit

@MainActor
final class NowPlayingManager {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?
    var onSeek: ((TimeInterval) -> Void)?

    // Store targets for cleanup
    private var commandTargets: [Any] = []

    init() {
        setupRemoteCommands()
    }

    deinit {
        let commandCenter = MPRemoteCommandCenter.shared()
        for target in commandTargets {
            commandCenter.playCommand.removeTarget(target)
            commandCenter.pauseCommand.removeTarget(target)
            commandCenter.nextTrackCommand.removeTarget(target)
            commandCenter.previousTrackCommand.removeTarget(target)
            commandCenter.changePlaybackPositionCommand.removeTarget(target)
        }
    }

    func update(song: Song, isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]

        if let album = song.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let albumArtist = song.albumArtist {
            info[MPMediaItemPropertyAlbumArtist] = albumArtist
        }
        if let trackNumber = song.trackNumber {
            info[MPMediaItemPropertyAlbumTrackNumber] = trackNumber
        }

        // Bug #8 fix: Add album artwork to lock screen
        if let image = song.coverArtImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        let playTarget = commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }
        commandTargets.append(playTarget)

        commandCenter.pauseCommand.isEnabled = true
        let pauseTarget = commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }
        commandTargets.append(pauseTarget)

        commandCenter.nextTrackCommand.isEnabled = true
        let nextTarget = commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNextTrack?()
            return .success
        }
        commandTargets.append(nextTarget)

        commandCenter.previousTrackCommand.isEnabled = true
        let prevTarget = commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPreviousTrack?()
            return .success
        }
        commandTargets.append(prevTarget)

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        let seekTarget = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.onSeek?(positionEvent.positionTime)
            }
            return .success
        }
        commandTargets.append(seekTarget)
    }
}
