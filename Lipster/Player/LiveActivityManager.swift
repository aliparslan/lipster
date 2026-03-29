import ActivityKit
import Foundation
import UIKit

/// Attributes for the Lipster playback Live Activity on the Dynamic Island.
struct LipsterPlaybackAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var songTitle: String
        var artistName: String
        var isPlaying: Bool
        var albumArtData: Data?
    }
}

@MainActor
final class LiveActivityManager {

    private var currentActivity: Activity<LipsterPlaybackAttributes>?

    func start(song: Song) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        end()

        let attributes = LipsterPlaybackAttributes()
        let state = LipsterPlaybackAttributes.ContentState(
            songTitle: song.title,
            artistName: song.artist,
            isPlaying: true,
            albumArtData: thumbnailData(for: song)
        )

        do {
            let content = ActivityContent(state: state, staleDate: nil)
            currentActivity = try Activity<LipsterPlaybackAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    func update(song: Song, isPlaying: Bool) {
        guard let activity = currentActivity else {
            if isPlaying {
                start(song: song)
            }
            return
        }

        let state = LipsterPlaybackAttributes.ContentState(
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

    func end() {
        guard let activity = currentActivity else { return }

        // Bug #12 fix: set currentActivity to nil inside the Task
        // to prevent race conditions with update() calling start()
        let activityToEnd = activity
        currentActivity = nil

        Task {
            let finalState = LipsterPlaybackAttributes.ContentState(
                songTitle: "",
                artistName: "",
                isPlaying: false,
                albumArtData: nil
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activityToEnd.end(content, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Helpers

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
