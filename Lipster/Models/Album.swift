import Foundation
import UIKit

struct Album: Identifiable, Hashable, Equatable, Sendable {
    let id: Int64
    let spotifyId: String?
    let name: String
    let artist: String
    let year: Int?
    let coverPath: String?

    /// The filesystem path to cover art, for use with ImageCache.
    var coverArtFilePath: String? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        // Try the cover_path stored in DB (e.g. "covers/albums/xyz.jpg")
        if let coverPath, !coverPath.isEmpty {
            let url = docs.appendingPathComponent(coverPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url.path
            }
        }
        // Fallback: look for cover.jpg in music/Artist/Album/
        let albumFolder = docs
            .appendingPathComponent("music")
            .appendingPathComponent(sanitizeFilename(artist))
            .appendingPathComponent(sanitizeFilename(name))
            .appendingPathComponent("cover.jpg")
        if FileManager.default.fileExists(atPath: albumFolder.path) {
            return albumFolder.path
        }
        return nil
    }

    /// Loads cover art via the shared ImageCache (avoids repeated disk I/O).
    var coverArtImage: UIImage? {
        guard let path = coverArtFilePath else { return nil }
        return ImageCache.shared.image(forPath: path)
    }

    private func sanitizeFilename(_ s: String) -> String {
        let illegal = "\\/:*?\"<>|"
        var result = s
        for ch in illegal { result = result.replacingOccurrences(of: String(ch), with: "_") }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
