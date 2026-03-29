import Foundation
import UIKit

struct Song: Identifiable, Hashable, Sendable {
    let id: Int64
    let spotifyId: String?
    let title: String
    let artist: String
    let albumArtist: String?
    let album: String?
    let year: Int?
    let trackNumber: Int?
    let discNumber: Int?
    let durationMs: Int
    let filePath: String
    let downloaded: Bool

    var durationFormatted: String {
        let totalSeconds = durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Resolves the full file URL in the app's Documents directory.
    var fileURL: URL? {
        guard !filePath.isEmpty,
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent(filePath)
    }

    /// Resolves cover.jpg from the same album folder as this song.
    var coverArtURL: URL? {
        guard let fileURL else { return nil }
        return fileURL.deletingLastPathComponent().appendingPathComponent("cover.jpg")
    }

    /// The filesystem path to cover art, for use with ImageCache.
    var coverArtPath: String? {
        guard let url = coverArtURL else { return nil }
        return url.path
    }

    /// Loads cover art via the shared ImageCache (avoids repeated disk I/O).
    var coverArtImage: UIImage? {
        guard let path = coverArtPath else { return nil }
        return ImageCache.shared.image(forPath: path)
    }
}
