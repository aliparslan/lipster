import UIKit

/// Centralized image cache backed by NSCache.
/// Eliminates repeated disk I/O from computed `coverArtImage` properties.
final class ImageCache: Sendable {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
    }

    /// Returns a cached image or loads from disk synchronously (for use in sync contexts).
    func image(forPath path: String) -> UIImage? {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
