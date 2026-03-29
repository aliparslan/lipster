import SwiftUI
import UIKit

// MARK: - SwiftUI Bridge

struct CoverFlowView: UIViewRepresentable {
    let albums: [Album]
    var centeredIndex: Binding<Int>?
    let onAlbumTapped: (Album) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CoverFlowUIView {
        let view = CoverFlowUIView()
        view.delegate = context.coordinator
        view.setAlbums(albums)
        return view
    }

    func updateUIView(_ uiView: CoverFlowUIView, context: Context) {
        context.coordinator.parent = self
        if uiView.albums != albums {
            uiView.setAlbums(albums)
        }
        // Sync programmatic index changes from SwiftUI → UIKit
        if let index = centeredIndex?.wrappedValue, index != uiView.currentIndex,
           albums.indices.contains(index) {
            uiView.scrollToIndex(index, animated: true)
        }
    }

    class Coordinator: CoverFlowUIViewDelegate {
        var parent: CoverFlowView

        init(parent: CoverFlowView) {
            self.parent = parent
        }

        func coverFlowDidScroll(toIndex index: Int) {
            parent.centeredIndex?.wrappedValue = index
        }

        func coverFlowDidTapCenter(atIndex index: Int) {
            guard parent.albums.indices.contains(index) else { return }
            parent.onAlbumTapped(parent.albums[index])
        }
    }
}

// MARK: - UIKit Cover Flow Engine

protocol CoverFlowUIViewDelegate: AnyObject {
    func coverFlowDidScroll(toIndex index: Int)
    func coverFlowDidTapCenter(atIndex index: Int)
}

class CoverFlowUIView: UIView {
    weak var delegate: CoverFlowUIViewDelegate?
    private(set) var albums: [Album] = []

    private let scrollView = UIScrollView()
    private var coverViews: [CoverItemView] = []

    // --- Classic Cover Flow constants (from Addy Osmani / Apple spec) ---
    private let coverSize: CGFloat = 160
    private let sideAngle: CGFloat = 45          // degrees — classic value
    private let sideSpacing: CGFloat = 38         // shows 2-3 per side comfortably
    private let centerGap: CGFloat = 60           // breathing room: center edge to first side item
    private let perspectiveM34: CGFloat = -1.0 / 500.0
    private let centerZPush: CGFloat = 30         // center item comes toward viewer

    private(set) var currentIndex: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        clipsToBounds = false

        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.decelerationRate = .fast
        scrollView.clipsToBounds = false
        addSubview(scrollView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scrollView.addGestureRecognizer(tap)
    }

    // Each item occupies this much horizontal space in the scroll content
    private var itemSlotWidth: CGFloat { sideSpacing }

    private var hasPerformedInitialLayout = false

    override func layoutSubviews() {
        super.layoutSubviews()
        let totalItemHeight = coverSize + coverSize * 0.3  // cover + reflection
        scrollView.frame = CGRect(
            x: 0,
            y: (bounds.height - totalItemHeight) / 2,
            width: bounds.width,
            height: totalItemHeight
        )
        updateContentSize()
        updateTransforms()

        if !hasPerformedInitialLayout && !albums.isEmpty && bounds.width > 0 {
            hasPerformedInitialLayout = true
            scrollToIndex(0, animated: false)
        }
    }

    func setAlbums(_ albums: [Album]) {
        self.albums = albums
        coverViews.forEach { $0.removeFromSuperview() }
        coverViews.removeAll()

        for (index, album) in albums.enumerated() {
            let itemView = CoverItemView(size: coverSize)
            scrollView.addSubview(itemView)
            coverViews.append(itemView)
            loadImage(for: album, index: index)
        }

        updateContentSize()
        setNeedsLayout()
    }

    private func loadImage(for album: Album, index: Int) {
        guard let path = album.coverArtFilePath else { return }
        let scale = window?.screen.scale ?? 3.0
        let targetPixels = coverSize * scale

        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: path)
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: targetPixels,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return }
            let image = UIImage(cgImage: cgImage)

            DispatchQueue.main.async { [weak self] in
                guard let self, index < self.coverViews.count else { return }
                self.coverViews[index].setImage(image)
            }
        }
    }

    // MARK: - Layout Math

    /// X position in scroll content for the center of item at `index`.
    private func centerX(forIndex index: Int) -> CGFloat {
        CGFloat(index) * itemSlotWidth + coverSize / 2
    }

    private func updateContentSize() {
        guard !albums.isEmpty, scrollView.bounds.width > 0 else { return }
        let totalWidth = CGFloat(albums.count - 1) * itemSlotWidth + coverSize
        let inset = (scrollView.bounds.width - coverSize) / 2
        scrollView.contentSize = CGSize(width: totalWidth, height: scrollView.bounds.height)
        scrollView.contentInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
    }

    private func updateTransforms() {
        let viewCenter = scrollView.contentOffset.x + scrollView.bounds.width / 2

        for (index, itemView) in coverViews.enumerated() {
            let itemCenter = centerX(forIndex: index)
            let distance = itemCenter - viewCenter
            let normalizedOffset = distance / itemSlotWidth  // continuous float

            // --- Smooth rotation ---
            // Interpolate: at offset 0 → 0°, ramps to full 45° by offset ±1, stays at 45° beyond
            let t_abs = min(abs(normalizedOffset), 1.0)  // clamp to [0, 1]
            let sign: CGFloat = normalizedOffset >= 0 ? -1 : 1
            // Use a curve that ramps quickly but smoothly (sine easing)
            let easedT = sin(t_abs * .pi / 2)  // 0→0, 0.5→0.71, 1→1
            let angleDeg = sign * sideAngle * easedT
            let angleRad = angleDeg * .pi / 180

            // --- Smooth position offset ---
            // Center item stays put; side items shift outward to create the gap
            // The shift ramps in over the first 1.0 of normalizedOffset
            let shiftSign: CGFloat = normalizedOffset >= 0 ? 1 : -1
            let shiftAmount = centerGap * easedT * shiftSign
            let sidePackOffset: CGFloat
            if abs(normalizedOffset) > 1.0 {
                // Beyond the first side item, pack tightly
                sidePackOffset = (abs(normalizedOffset) - 1.0) * sideSpacing * shiftSign
            } else {
                sidePackOffset = 0
            }
            let x = itemCenter - coverSize / 2 + shiftAmount + sidePackOffset

            itemView.frame = CGRect(x: x, y: 0, width: coverSize, height: coverSize)

            // --- Smooth Z depth ---
            let zPush = centerZPush * (1.0 - easedT)

            var t = CATransform3DIdentity
            t.m34 = perspectiveM34
            t = CATransform3DTranslate(t, 0, 0, zPush)
            t = CATransform3DRotate(t, angleRad, 0, 1, 0)

            itemView.layer.transform = t
            itemView.layer.zPosition = 1000 - abs(normalizedOffset) * 100

            // Reflection fades for distant items — only visible within ±2 items
            let reflectionAlpha = abs(normalizedOffset) <= 2 ? max(0, 0.3 - abs(normalizedOffset) * 0.1) : 0
            itemView.reflectionView.alpha = reflectionAlpha
        }
    }

    // MARK: - Snapping

    private func snapToNearest() {
        let viewCenter = scrollView.contentOffset.x + scrollView.bounds.width / 2
        var bestIndex = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for i in albums.indices {
            let d = abs(centerX(forIndex: i) - viewCenter)
            if d < bestDist { bestDist = d; bestIndex = i }
        }
        scrollToIndex(bestIndex, animated: true)
    }

    func scrollToIndex(_ index: Int, animated: Bool) {
        let targetOffsetX = centerX(forIndex: index) - scrollView.bounds.width / 2
        scrollView.setContentOffset(CGPoint(x: targetOffsetX, y: 0), animated: animated)
        if currentIndex != index {
            currentIndex = index
            delegate?.coverFlowDidScroll(toIndex: index)
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let loc = gesture.location(in: scrollView)
        let viewCenter = scrollView.contentOffset.x + scrollView.bounds.width / 2
        let centerItemX = centerX(forIndex: currentIndex)

        if abs(loc.x - centerItemX) < coverSize / 2 && loc.y < coverSize {
            delegate?.coverFlowDidTapCenter(atIndex: currentIndex)
        } else {
            // Tap on a side item: find which one and scroll to it
            for i in albums.indices {
                let frame = coverViews[i].frame
                if frame.contains(loc) {
                    scrollToIndex(i, animated: true)
                    return
                }
            }
        }
    }
}

// MARK: - UIScrollViewDelegate

extension CoverFlowUIView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateTransforms()
        let viewCenter = scrollView.contentOffset.x + scrollView.bounds.width / 2
        var bestIndex = 0
        var bestDist = CGFloat.greatestFiniteMagnitude
        for i in albums.indices {
            let d = abs(centerX(forIndex: i) - viewCenter)
            if d < bestDist { bestDist = d; bestIndex = i }
        }
        if bestIndex != currentIndex {
            currentIndex = bestIndex
            delegate?.coverFlowDidScroll(toIndex: bestIndex)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { snapToNearest() }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        snapToNearest()
    }
}

// MARK: - Cover Item View (image + reflection)

private class CoverItemView: UIView {
    let imageView = UIImageView()
    let reflectionView = UIImageView()
    private let coverSize: CGFloat

    init(size: CGFloat) {
        self.coverSize = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        clipsToBounds = false

        // Main image
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray5
        imageView.frame = bounds
        addSubview(imageView)

        // Placeholder
        let ph = UIImageView(image: UIImage(systemName: "music.note"))
        ph.tintColor = .tertiaryLabel
        ph.contentMode = .scaleAspectFit
        ph.frame = CGRect(x: size * 0.3, y: size * 0.3, width: size * 0.4, height: size * 0.4)
        ph.tag = 999
        imageView.addSubview(ph)

        // Reflection: flipped copy below the cover
        reflectionView.contentMode = .scaleAspectFill
        reflectionView.clipsToBounds = true
        reflectionView.alpha = 0.3
        let rh = size * 0.3
        reflectionView.frame = CGRect(x: 0, y: size, width: size, height: rh)
        reflectionView.transform = CGAffineTransform(scaleX: 1, y: -1)
        addSubview(reflectionView)

        // Gradient fade on reflection
        // The reflectionView is flipped (scaleY: -1), so in its layer coordinate space:
        //   y=0 is the bottom of the reflection (far from cover) → should be transparent
        //   y=1 is the top of the reflection (near the cover) → should be opaque
        let grad = CAGradientLayer()
        grad.colors = [UIColor.clear.cgColor, UIColor.white.cgColor]
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint = CGPoint(x: 0.5, y: 0.7)
        grad.frame = CGRect(x: 0, y: 0, width: size, height: rh)
        reflectionView.layer.mask = grad

        // Shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }

    required init?(coder: NSCoder) { fatalError() }

    func setImage(_ image: UIImage) {
        imageView.image = image
        reflectionView.image = image
        imageView.viewWithTag(999)?.removeFromSuperview()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        let rh = coverSize * 0.3
        reflectionView.frame = CGRect(x: 0, y: coverSize, width: coverSize, height: rh)
        if let grad = reflectionView.layer.mask as? CAGradientLayer {
            grad.frame = CGRect(x: 0, y: 0, width: coverSize, height: rh)
        }
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }
}

#Preview {
    CoverFlowView(albums: []) { _ in }
        .preferredColorScheme(.dark)
}
