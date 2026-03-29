import SwiftUI
import UIKit

/// Extracts dominant colors from a UIImage for use in ambient backgrounds.
/// Uses Core Image's CIAreaAverage and sampling to find primary + secondary colors.
struct AlbumColors: Equatable {
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let isDark: Bool

    static let placeholder = AlbumColors(
        primary: Color(.systemGray4),
        secondary: Color(.systemGray5),
        tertiary: Color(.systemGray6),
        isDark: true
    )
}

@MainActor
final class ColorExtractor {
    static let shared = ColorExtractor()

    private var cache: [String: AlbumColors] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheSize = 50

    func extract(from image: UIImage, cacheKey: String? = nil) -> AlbumColors {
        if let key = cacheKey, let cached = cache[key] {
            return cached
        }

        guard let cgImage = image.cgImage else { return .placeholder }

        let colors = dominantColors(from: cgImage)
        let result = AlbumColors(
            primary: Color(uiColor: colors.0),
            secondary: Color(uiColor: colors.1),
            tertiary: Color(uiColor: colors.2),
            isDark: colors.0.isLight == false
        )

        if let key = cacheKey {
            cache[key] = result
            cacheOrder.append(key)
            // Evict oldest entries when cache exceeds limit
            while cacheOrder.count > maxCacheSize {
                let evicted = cacheOrder.removeFirst()
                cache.removeValue(forKey: evicted)
            }
        }
        return result
    }

    private func dominantColors(from cgImage: CGImage) -> (UIColor, UIColor, UIColor) {
        let width = 50
        let height = 50
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (.systemGray, .systemGray2, .systemGray3)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Sample colors from different regions
        let topColor = averageColor(pixelData: pixelData, width: width, region: CGRect(x: 0, y: 0, width: width, height: height / 3))
        let midColor = averageColor(pixelData: pixelData, width: width, region: CGRect(x: 0, y: height / 3, width: width, height: height / 3))
        let botColor = averageColor(pixelData: pixelData, width: width, region: CGRect(x: 0, y: 2 * height / 3, width: width, height: height / 3))

        // Darken colors for background use
        return (
            topColor.adjusted(saturation: 1.3, brightness: 0.5),
            midColor.adjusted(saturation: 1.3, brightness: 0.4),
            botColor.adjusted(saturation: 1.3, brightness: 0.3)
        )
    }

    private func averageColor(pixelData: [UInt8], width: Int, region: CGRect) -> UIColor {
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var count: CGFloat = 0

        let minX = Int(region.minX)
        let maxX = Int(region.maxX)
        let minY = Int(region.minY)
        let maxY = Int(region.maxY)

        for y in minY..<maxY {
            for x in minX..<maxX {
                let offset = (y * width + x) * 4
                guard offset + 3 < pixelData.count else { continue }
                totalR += CGFloat(pixelData[offset]) / 255.0
                totalG += CGFloat(pixelData[offset + 1]) / 255.0
                totalB += CGFloat(pixelData[offset + 2]) / 255.0
                count += 1
            }
        }

        guard count > 0 else { return .systemGray }
        return UIColor(red: totalR / count, green: totalG / count, blue: totalB / count, alpha: 1)
    }
}

extension UIColor {
    var isLight: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: nil)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.5
    }

    func adjusted(saturation: CGFloat, brightness: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(
            hue: h,
            saturation: min(s * saturation, 1),
            brightness: min(b * brightness, 1),
            alpha: a
        )
    }
}
