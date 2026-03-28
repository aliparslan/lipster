import ActivityKit
import Foundation
import UIKit

/// Attributes for the Mojo playback Live Activity on the Dynamic Island.
struct MojoPlaybackAttributes: ActivityAttributes {
    /// Static context that doesn't change during the activity lifetime.
    struct ContentState: Codable, Hashable {
        var songTitle: String
        var artistName: String
        var isPlaying: Bool
        var albumArtData: Data?
    }
}

/// Manages the ActivityKit Live Activity for music playback on the Dynamic Island.
/// The widget extension UI must be added via Xcode; this class handles
/// starting, updating, and ending the activity from the main app.
@MainActor
final class LiveActivityManager {

    private var currentActivity: Activity<MojoPlaybackAttributes>?

    /// Start a new Live Activity when playback begins.
    func start(song: Song) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Activities not enabled")
            return
        }

        // End any existing activity first
        end()

        let attributes = MojoPlaybackAttributes()
        let state = MojoPlaybackAttributes.ContentState(
            songTitle: song.title,
            artistName: song.artist,
            isPlaying: true,
            albumArtData: thumbnailData(for: song)
        )

        do {
            let content = ActivityContent(state: state, staleDate: nil)
            currentActivity = try Activity<MojoPlaybackAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    /// Update the Live Activity when the song changes or play/pause state changes.
    func update(song: Song, isPlaying: Bool) {
        guard let activity = currentActivity else {
            // If no activity exists yet and we're playing, start one
            if isPlaying {
                start(song: song)
            }
            return
        }

        let state = MojoPlaybackAttributes.ContentState(
            songTitle: song.title,
            artistName: song.artist,
            isPlaying: isPlaying,
            albumArtData: thumbnailData(for: song)
        )

        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
    }

    /// End the Live Activity when playback stops.
    func end() {
        guard let activity = currentActivity else { return }

        Task {
            let finalState = MojoPlaybackAttributes.ContentState(
                songTitle: "",
                artistName: "",
                isPlaying: false,
                albumArtData: nil
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .immediate)
        }

        currentActivity = nil
    }

    // MARK: - Helpers

    /// Generate a small thumbnail Data from the song's cover art for the Dynamic Island.
    private func thumbnailData(for song: Song) -> Data? {
        guard let image = song.coverArtImage else { return nil }
        let size = CGSize(width: 80, height: 80)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return thumbnail.jpegData(compressionQuality: 0.6)
    }
}
