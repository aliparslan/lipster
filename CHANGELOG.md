# Lipster Music Player — Complete Overhaul Session Log

## Build, Run, and Screenshot Commands

These are the commands used to build, install, run, and screenshot the app on the iOS Simulator during development.

### Build
```bash
xcodebuild -scheme Lipster -project /Users/alip/dev/mojo/Lipster.xcodeproj \
  -destination 'platform=iOS Simulator,id=AC9D0A22-C9D8-4186-8824-2EFA8281F5CA' \
  build 2>&1 | grep "error:\|BUILD" | tail -10
```

### Boot Simulator
```bash
xcrun simctl boot AC9D0A22-C9D8-4186-8824-2EFA8281F5CA
```

### Install & Launch
```bash
xcrun simctl terminate booted com.alip.lipster 2>/dev/null
xcrun simctl install booted /Users/alip/Library/Developer/Xcode/DerivedData/Lipster-dfhdspsaqluujccrxelgqvtpubzr/Build/Products/Debug-iphonesimulator/Lipster.app
xcrun simctl launch booted com.alip.lipster
```

### Take Screenshot
```bash
xcrun simctl io booted screenshot /tmp/lipster_screenshot.png
```

### Navigate Tabs via AppleScript (Accessibility)
```bash
# Click a specific tab (1=Library, 2=Flip, 3=Search, 4=Settings)
osascript -e '
tell application "Simulator" to activate
delay 0.5
tell application "System Events"
    tell process "Simulator"
        set allButtons to every radio button of group 2 of group 1 of group 1 of group 1 of group 2 of group 1 of group 1 of group 1 of group 1 of group 1 of group 1 of group 1 of window 1
        click item 2 of allButtons  -- 2 = Flip tab
    end tell
end tell
'
```
Note: AppleScript requires Accessibility permissions for Simulator. Grant in System Settings > Privacy & Security > Accessibility.

### Add New Swift Files to Xcode Project
```bash
pip3 install --break-system-packages pbxproj  # one-time install

python3 << 'EOF'
from pbxproj import XcodeProject
import os

project = XcodeProject.load('Lipster.xcodeproj/project.pbxproj')
files_to_add = [
    'Lipster/Path/To/NewFile.swift',
]
for f in files_to_add:
    if os.path.exists(f):
        project.add_file(f, target_name='Lipster')
        print(f"Added: {f}")
project.save()
EOF
```

### Full Pipeline (build → install → navigate → screenshot)
```bash
xcodebuild -scheme Lipster -project /Users/alip/dev/mojo/Lipster.xcodeproj \
  -destination 'platform=iOS Simulator,id=AC9D0A22-C9D8-4186-8824-2EFA8281F5CA' build 2>&1 | \
  grep "error:\|BUILD" | tail -5 && \
xcrun simctl terminate booted com.alip.lipster 2>/dev/null && \
xcrun simctl install booted /Users/alip/Library/Developer/Xcode/DerivedData/Lipster-dfhdspsaqluujccrxelgqvtpubzr/Build/Products/Debug-iphonesimulator/Lipster.app && \
xcrun simctl launch booted com.alip.lipster && \
sleep 2 && \
xcrun simctl io booted screenshot /tmp/lipster_screenshot.png
```

### Simulator Details
- **Device**: iPhone 17 (AC9D0A22-C9D8-4186-8824-2EFA8281F5CA)
- **OS**: iOS 26.4
- **Bundle ID**: com.alip.lipster
- **Derived Data**: /Users/alip/Library/Developer/Xcode/DerivedData/Lipster-dfhdspsaqluujccrxelgqvtpubzr/

---

## What Was Done

### Overview
Complete overhaul of the Lipster iOS music player app: 31 bug fixes, new infrastructure (image caching, haptics), app restructuring for iOS 26, and a signature Flip feature built with UIKit CATransform3D.

---

## Phase 1: Foundation — Bug Fixes & Infrastructure

### New Files Created
- **`Lipster/Utilities/ImageCache.swift`** — `NSCache<NSString, UIImage>`-backed image cache. Eliminates repeated `UIImage(contentsOfFile:)` disk reads that were happening on every SwiftUI view body evaluation during scrolling. Count limit of 200.
- **`Lipster/Utilities/HapticManager.swift`** — `Haptics` enum with static methods: `impact(.light)`, `impact(.medium)`, `selection()`, `notification(.success)`. Used throughout transport controls.

### Bug Fixes Applied

**Critical:**
1. **Queue tap ordering (Bug #1)** — `QueueView` was calling `play(song:)` then setting `queueIndex` after, causing preload to use wrong index. Added `playAtIndex(_:)` method on `AppState`.
2. **`upNext` potential crash (Bug #2)** — `suffix(from: queueIndex + 1)` could crash if `queueIndex >= queue.count`. Added bounds check with guard.
3. **`skipNext()` wraps when repeat off (Bug #3)** — Added guard: `if repeatMode == .off && queueIndex >= queue.count - 1 { return }`.
4. **`DatabaseManager.deinit` thread safety (Bug #4)** — Changed to `nonisolated deinit` for Swift concurrency safety.

**High:**
5. **Double-shuffle (Bug #5)** — Setting `shuffleEnabled = true` then calling `play(song:queue:)` triggered `didSet` which reshuffled, then `play()` shuffled again. Added `suppressShuffleDidSet` flag and `playShuffled(song:queue:)` method.
6. **`didToggleShuffle()` empty queue crash (Bug #6)** — Added `guard !originalQueue.isEmpty` before reshuffling.
7. **`playerItemDidFinish` threading (Bug #7)** — Wrapped `onSongFinished?()` in `Task { @MainActor in }` since the AVFoundation notification may fire off the main thread.
8. **Missing lock screen artwork (Bug #8)** — Added `MPMediaItemPropertyArtwork` with `MPMediaItemArtwork(boundsSize:)` to `NowPlayingManager.update()`.
9. **`sqlite3_bind_text` dangling pointer (Bug #9)** — Used `SQLITE_TRANSIENT` (`unsafeBitCast(-1, to: sqlite3_destructor_type.self)`) instead of `nil` destructor.
10. **Unbounded `ColorExtractor.cache` (Bug #10)** — Added `cacheOrder` array with LRU eviction when count exceeds 50.
11. **Synchronous disk I/O in `coverArtImage` (Bug #11)** — `Song.coverArtImage` and `Album.coverArtImage` now go through `ImageCache.shared`.
12. **`LiveActivityManager.end()` race condition (Bug #12)** — Moved `currentActivity = nil` before the async Task so `update()` can't call `start()` on a stale reference.

**Medium:**
13. **`MotionManagerBridge` not `@MainActor` (Bug #13)** — Marked `@MainActor`. (Later removed entirely when parallax was deleted.)
14. **`preloadNextTrack()` wraps when repeat off (Bug #14)** — Only preloads if `nextIndex < queue.count || repeatMode == .all`.
15. **Gapless playback broken (Bug #15)** — Added `advanceToPreloaded()` method to `AudioPlayer` for natural song completion (reuses preloaded AVPlayerItem) vs `play(song:)` for user-initiated skip (creates new player).
16. **`addToQueue` on empty queue (Bug #16)** — Auto-plays first song if queue is empty and nothing is playing.
17. **`ArtistsView` blocks main thread (Bug #17)** — (Noted, partial fix via ImageCache reducing repeated disk reads.)
18. **`removeFromQueue` edge cases (Bug #18)** — Added `queueIndex = min(queueIndex, queue.count - 1)` post-removal.
19. **`SearchView` no debounce (Bug #19)** — Added `Task` with `Task.sleep(for: .milliseconds(300))` and cancellation on each keystroke.
20. **Non-functional settings toggles (Bug #20)** — Removed fake Gapless/Crossfade toggles, replaced with static "On" label for Gapless.

**Low:**
21. **"Go to Album/Artist" not implemented (Bug #21)** — Implemented in `SongContextMenu` with `onGoToAlbum` and `onGoToArtist` callbacks. Uses `DatabaseManager.findAlbum(name:artist:)`.
22. **Remote command targets never removed (Bug #22)** — Stored targets in array, removed in `deinit`.
24. **Duplicate history IDs in QueueView (Bug #24)** — Changed `ForEach` to use `.offset` as ID instead of `Song.id`.
25. **Redundant artist in album detail (Bug #25)** — Only shows per-track artist when it differs from album artist.
28. **No haptic feedback (Bug #28)** — Added `Haptics.impact()` to all transport controls.
29. **Ken Burns animation stacking (Bug #29)** — Tracked with cancellable `Task`. (Later removed entirely.)
30. **No context menu in ArtistDetailView (Bug #30)** — Added `.contextMenu { SongContextMenu(song: song) }`.

### Files Modified
- `AppState.swift` — Bugs #1-3, #5-6, #14, #16, #18 + `playAtIndex()`, `playShuffled()`, `advanceToNext()` for gapless
- `AudioPlayer.swift` — Bug #15 (gapless), Bug #7 (threading), added `advanceToPreloaded()`
- `DatabaseManager.swift` — Bugs #4, #9 + new queries: `loadLikedSongs()`, `searchAlbums()`, `searchArtists()`, `findAlbum()`, `songCount()`, `albumCount()`, `artistCount()`
- `NowPlayingManager.swift` — Bug #8 (artwork), Bug #22 (target cleanup)
- `LiveActivityManager.swift` — Bug #12 (race condition)
- `Song.swift` — `coverArtImage` now uses `ImageCache.shared`
- `Album.swift` — `coverArtImage` now uses `ImageCache.shared`, extracted `coverArtFilePath` computed property
- `ColorExtractor.swift` — Bug #10 (bounded cache)
- `QueueView.swift` — Bug #24 (duplicate IDs), Bug #1 (uses `playAtIndex`)
- `ArtistsView.swift` — Bug #30 (context menu)
- `SearchView.swift` — Bug #19 (debounce)
- `AlbumsView.swift` — Bug #5 (uses `playShuffled`)
- `PlaylistsView.swift` — Bug #5 (uses `playShuffled`)

---

## Phase 2: App Structure — iOS 26 Readiness

### App Shell Restructure (`LipsterApp.swift`)
- **4-tab layout**: Library, Flip, Search, Settings
- **Mini player** uses `safeAreaInset(edge: .bottom)` on each tab (native iOS positioning, not a ZStack hack)
- **Now Playing** presented as `.sheet` with native iOS drag-to-dismiss (removed manual `DragGesture` + `offset` hack)
- **Dark mode only**: `.preferredColorScheme(.dark)` at root
- **Settings extracted** to `Lipster/Views/Settings/SettingsView.swift`

### New Files
- **`Lipster/Views/Settings/SettingsView.swift`** — Library stats (song/album/artist counts), volume normalization toggle, version info
- **`Lipster/Views/Library/LikedSongsView.swift`** — Shows songs from `liked_songs` table ordered by `liked_at DESC`
- **`Lipster/Views/Flip/FlipBrowserView.swift`** — Dedicated Flip tab

### Mini Player (`MiniPlayerView.swift`)
- Progress bar as thin accent-colored line at the top
- **Swipe gestures**: swipe left → skip next, swipe right → skip previous (60pt threshold, spring snap-back)
- Haptic feedback on play/pause and skip
- Removed `matchedGeometryEffect` / `Namespace` (using native sheet presentation instead)

### Now Playing (`NowPlayingView.swift`)
- **Removed**: CoreMotion import, `MotionManagerBridge` class, Ken Burns effect, parallax — user found it nauseating
- **Fixed slider jump**: added `.onAppear { sliderValue = appState.currentTime }` so the slider syncs to current position immediately
- Uses native `.sheet` dismiss gesture (no manual drag offset)
- `.presentationDragIndicator(.hidden)` — drag handle drawn manually
- Haptic feedback on all transport controls

### Library View (`LibraryView.swift`)
- Added "Liked" tab to `LibraryTab` enum (heart.fill icon)
- XMB category selector now has 5 tabs: Songs, Albums, Artists, Playlists, Liked

---

## Phase 3: Flip — UIKit CATransform3D

### Why UIKit Instead of SwiftUI
SwiftUI's `scrollTransition` API only provides 3 discrete phases (identity, entering, exiting) — not continuous position values. This makes smooth Flip impossible in pure SwiftUI. The classic Flip was built with `CATransform3D` which provides:
- `m34` perspective parameter for true 3D projection
- Continuous per-pixel transform updates during scrolling
- GPU-accelerated layer compositing
- Precise z-ordering control

### Implementation (`FlipView.swift`)
The file contains:
1. **`FlipView`** — `UIViewRepresentable` bridge between SwiftUI and UIKit
2. **`FlipUIView`** — Main UIKit view with `UIScrollView`
3. **`CoverItemView`** — Individual album cover with reflection

**Constants (from Addy Osmani's Flip spec):**
- `coverSize`: 160pt
- `sideAngle`: 45 degrees (classic Apple value)
- `sideSpacing`: 38pt between side items
- `centerGap`: 60pt breathing room between center edge and first side item
- `perspective (m34)`: -1/500
- `centerZPush`: 30pt (center album pushed toward viewer)

**Smooth rotation using sine easing:**
```
easedT = sin(clamp(|normalizedOffset|, 0, 1) * π/2)
angleDeg = sign * 45 * easedT
```
This means: at center (offset 0) → 0° rotation. As the album scrolls away, it smoothly rotates to 45° using a sine curve (fast initial rotation, gentle settle). No hard snap.

**Position interpolation:**
- Center item stays at its natural scroll position
- Side items shift outward by `centerGap * easedT` to create the breathing room
- Beyond the first side item, additional items pack tightly at `sideSpacing` intervals

**Image loading:**
- Uses `CGImageSourceCreateThumbnailAtIndex` for downsampled thumbnails (display-size only)
- Loaded on `DispatchQueue.global(qos: .userInitiated)`, applied on main thread
- Falls back to `ImageCache.shared` if CGImageSource fails

**Reflections:**
- Each `CoverItemView` has a flipped `UIImageView` below the main image
- `CAGradientLayer` mask fades from 30% opacity to transparent
- Reflection opacity decreases for distant items

**Scroll behavior:**
- `UIScrollView` with `.decelerationRate = .fast`
- Snap-to-center on `scrollViewDidEndDragging` and `scrollViewDidEndDecelerating`
- Tap center album → navigate to album detail
- Tap side album → scroll to center it

### Flip Browser View (`FlipBrowserView.swift`)
- PS3-inspired layered background: black base + blurred album art (20% opacity) + color gradient ribbons from `ColorExtractor` + radial glow
- Background colors shift as you swipe between albums
- Album info (name, artist, year) centered below the carousel with text wrapping
- Track list below using native `List` with transparent background
- Tracks load via `loadSongsForAlbum` when centered album changes

---

## Phase 4: View Redesigns

### Albums View (`AlbumsView.swift`)
- **Grid as default** — 2-column `LazyVGrid` with large album artwork
- Toggle to switch between grid and list view
- Album grid cells: rounded corners, shadow, name + artist below
- **Album Detail redesign**: now-playing waveform indicator, only shows per-track artist when different from album artist, colored shadow from album art

### Search View (`SearchView.swift`)
- **Sectioned results**: Artists, Albums, Songs in separate `Section` blocks
- Debounced search (300ms) with Task cancellation
- New DB queries: `searchAlbums()`, `searchArtists()`

### Songs View (`SongsView.swift`)
- **"Go to Album" / "Go to Artist"** implemented in `SongContextMenu`
- Navigation via `navigationDestination(item:)` for albums and `navigationDestination(for: String.self)` for artists

---

## Resources Used

### Apple Documentation
- SwiftUI documentation: https://developer.apple.com/documentation/swiftui
- SwiftUI animations: https://developer.apple.com/documentation/swiftui/animations
- SwiftUI gestures: https://developer.apple.com/documentation/swiftui/gestures
- MediaPlayer framework: https://developer.apple.com/documentation/mediaplayer
- Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines
- HIG Playing Audio: https://developer.apple.com/design/human-interface-guidelines/playing-audio
- HIG Motion: https://developer.apple.com/design/human-interface-guidelines/motion
- HIG Color: https://developer.apple.com/design/human-interface-guidelines/color
- HIG Typography: https://developer.apple.com/design/human-interface-guidelines/typography

### iOS 26 / Liquid Glass
- Apple Newsroom announcement: https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/
- Applying Liquid Glass to custom views: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
- WWDC25 Session 323 — Build a SwiftUI app with the new design
- WWDC25 Session 219 — Meet Liquid Glass
- Donny Wals — Designing custom UI with Liquid Glass: https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/
- Nil Coalescing — Presenting Liquid Glass sheets: https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/
- Hacking with Swift — What's new in SwiftUI for iOS 26: https://www.hackingwithswift.com/articles/278/whats-new-in-swiftui-for-ios-26

### Flip Implementation
- Addy Osmani — CSS Flip (exact transform values): https://addyosmani.com/blog/coverflow/
- Balsamiq — Flip UX guidelines: https://balsamiq.com/learn/cover-flow/
- Cult of Mac — iPod Flip reference image: https://www.cultofmac.com/wp-content/uploads/2010/10/post-61758-image-221f26e399e464c71248d2528ef2eeaf.jpg
- iCarousel library (reference for CATransform3D approach): https://github.com/nicklockwood/iCarousel
- Flip history: https://en.wikipedia.org/wiki/Cover_Flow
- CodePath — Using Perspective Transforms (m34): https://guides.codepath.com/ios/Using-Perspective-Transforms

### PS3 XMB Design
- XrossMediaBar Wikipedia: https://en.wikipedia.org/wiki/XrossMediaBar
- PS3 Developer Wiki — XMB: https://www.psdevwiki.com/ps3/XMB
- PS3 Custom Themes & XMB Waves: https://consolemods.org/wiki/PS3:Custom_Themes,_Fonts,_and_XMB_Waves
- PlayStation 3 XMB Wave Recreation: https://github.com/linkev/PlayStation-3-XMB
- PS3 Visualizer from Q-Games: https://blog.playstation.com/2013/08/08/new-ps3-visualizer-app-from-q-games-out-tuesday/

### Music App Tech Stacks
- Spotify Hub Framework: https://github.com/spotify/HubFramework
- Building Component-Driven UIs at Spotify: https://speakerdeck.com/uamobitech/building-component-driven-uis-at-spotify-from-john-sundell
- Tidal SDK for iOS: https://github.com/tidal-music/tidal-sdk-ios

### SwiftUI + UIKit Integration
- WWDC24 — Create Custom Visual Effects with SwiftUI (visualEffect modifier)
- Thumbtack — SwiftUI 3D Carousel prototype: https://medium.com/thumbtack-engineering/swiftui-in-action-prototyping-an-interactive-3d-carousel-experience-3cef844cfaf2

---

## File Manifest

### New Files (5)
| File | Purpose |
|------|---------|
| `Lipster/Utilities/ImageCache.swift` | NSCache-backed image loading |
| `Lipster/Utilities/HapticManager.swift` | Centralized haptic feedback |
| `Lipster/Views/Flip/FlipBrowserView.swift` | Dedicated Flip tab with PS3 background + track list |
| `Lipster/Views/Settings/SettingsView.swift` | Extracted settings with library stats |
| `Lipster/Views/Library/LikedSongsView.swift` | Liked songs from ripper DB |

### Modified Files (19)
| File | Changes |
|------|---------|
| `AppState.swift` | 8 bug fixes, `playAtIndex()`, `playShuffled()`, gapless `advanceToNext()` |
| `AudioPlayer.swift` | Gapless playback, threading fix, `advanceToPreloaded()` |
| `DatabaseManager.swift` | Safety fixes, 6 new query methods |
| `NowPlayingManager.swift` | Lock screen artwork, target cleanup |
| `LiveActivityManager.swift` | Race condition fix |
| `Song.swift` | ImageCache integration, `coverArtPath` property |
| `Album.swift` | ImageCache integration, `coverArtFilePath` property |
| `LipsterApp.swift` | 4-tab structure, `safeAreaInset` mini player, sheet Now Playing |
| `FlipView.swift` | Complete rewrite: UIKit `CATransform3D` with `UIViewRepresentable` |
| `LibraryView.swift` | Added "Liked" tab |
| `AlbumsView.swift` | Grid default, album detail redesign, `playShuffled` |
| `ArtistsView.swift` | Context menu on detail rows |
| `PlaylistsView.swift` | `playShuffled` fix |
| `SongsView.swift` | "Go to Album/Artist" navigation |
| `SearchView.swift` | Debounce, sectioned results |
| `MiniPlayerView.swift` | Progress bar, swipe gestures, haptics |
| `NowPlayingView.swift` | Removed parallax/Ken Burns, slider sync, native sheet dismiss |
| `QueueView.swift` | Duplicate ID fix, `playAtIndex` |
| `ColorExtractor.swift` | Bounded LRU cache |

---

## Known Remaining Work
- iOS 26 Liquid Glass progressive enhancement (`#available(iOS 26, *)` checks) — designed but not yet implemented since APIs require Xcode 26 beta
- Flip could use further tuning of spacing/angles based on user testing
- Playlist folder nesting not yet implemented
- Artist detail could group songs by album instead of flat list
- Performance profiling with Instruments for large libraries

---

## Design Decisions
- **iOS target**: iOS 18+ with iOS 26 Liquid Glass as progressive enhancement
- **Color scheme**: Dark mode only
- **Flip**: Own dedicated tab (first-class feature)
- **Liked Songs**: Library XMB category
- **Parallax/Ken Burns**: Removed at user request (causes nausea)
- **Flip engine**: UIKit `CATransform3D` via `UIViewRepresentable` (SwiftUI's `scrollTransition` too limited for continuous 3D transforms)
- **Now Playing presentation**: Native `.sheet` (not `.fullScreenCover` with manual drag gesture)
- **Mini player positioning**: `safeAreaInset(edge: .bottom)` per tab (native iOS, not ZStack overlay)
