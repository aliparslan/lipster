---
name: Lipster Music Player
description: iOS music player app (SwiftUI + UIKit Cover Flow) that plays local music from a ripper.db SQLite database
type: project
---

Lipster is a native iOS music player built with SwiftUI (UIKit for Cover Flow) targeting local music files.

**Architecture:** Single `@Observable` AppState with AVQueuePlayer, SQLite3 (read-only ripper.db), NowPlayingManager (MPRemoteCommandCenter), LiveActivityManager (Dynamic Island). ImageCache (NSCache) for album art. Haptics on all controls.

**Key detail:** The app does NOT use Apple's MediaPlayer/MusicKit frameworks for library access. It reads from a custom `ripper.db` SQLite database in the Documents folder, with music files stored as `Documents/music/{Artist}/{Album}/`. This is a "ripper" workflow — music is synced/transferred externally.

**Companion tool:** `/Users/alip/dev/ripper` is a Python CLI tool that populates ripper.db. It imports from Spotify (OAuth + spotipy) or Apple Music (Library.xml), downloads audio from YouTube via yt-dlp at 320kbps MP3, fetches cover art from iTunes/MusicBrainz, and writes ID3 tags with mutagen. The DB schema includes: songs, albums, playlists, folders, album_songs, playlist_songs, liked_songs.

**Cover Flow:** Built with UIKit `CATransform3D` via `UIViewRepresentable` because SwiftUI's `scrollTransition` API is too limited for continuous 3D transforms. Uses 45-degree side rotation, sine easing for smooth transitions, `m34 = -1/500` perspective, downsampled thumbnails via `CGImageSourceCreateThumbnailAtIndex`. Reference: Addy Osmani's Cover Flow spec.

**Current state (2026-03-28):** 31 bugs fixed, 5 new files, 19 modified files. All phases complete. Cover Flow still needs tuning (spacing, text clipping in track list). See `/Users/alip/dev/mojo/CHANGELOG.md` for full details.

**Why:** The user wants to create an awesome iOS music player with a great UX, inspired by Apple Music, classic Cover Flow, and PS3 XMB.

**How to apply:** All library/playback features should work with the existing SQLite + local file architecture, not MPMediaQuery. The ripper DB schema is the source of truth. Cover Flow must use UIKit CATransform3D, not SwiftUI scrollTransition.
