---
name: Flip must use UIKit CATransform3D
description: SwiftUI scrollTransition is too limited for Flip — always use UIKit UIViewRepresentable
type: feedback
---

Flip MUST be built with UIKit `CATransform3D` wrapped in `UIViewRepresentable`. Do not attempt SwiftUI-only Flip.

**Why:** We tried 4+ iterations of SwiftUI Flip using `scrollTransition`, `scaleEffect`, negative spacing, etc. All looked wrong — distorted scaling, laggy scrolling, hard rotation snaps. SwiftUI's `scrollTransition` only provides 3 discrete phases, not continuous position values needed for smooth 3D transforms. The user explicitly asked about tech stacks and agreed UIKit was the right approach.

**How to apply:** The Flip component is in `FlipView.swift` as a `UIViewRepresentable`. The key constants are: 45° side angle, `m34 = -1/500` perspective, sine easing for smooth rotation, `CGImageSourceCreateThumbnailAtIndex` for performance. Reference: https://addyosmani.com/blog/coverflow/
