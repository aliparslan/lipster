import SwiftUI

enum LibraryCategory: String, CaseIterable {
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"

    var icon: String {
        switch self {
        case .albums: "square.stack"
        case .artists: "person.2"
        case .playlists: "music.note.list"
        }
    }
}

struct ArtistItem: Equatable {
    let name: String
    let coverArtFilePath: String?
}

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @Namespace private var namespace

    // Category & carousel state
    @State private var selectedCategory: LibraryCategory = .albums
    @State private var centeredIndex: Int = 0

    // Data per category
    @State private var albums: [Album] = []
    @State private var artistItems: [ArtistItem] = []
    @State private var playlists: [Playlist] = []

    // Display state — only updated after flipping settles (debounced)
    @State private var displayIndex: Int = 0
    @State private var albumColors: AlbumColors = .placeholder
    @State private var tracks: [Song] = []
    @State private var artistAlbumGroups: [(album: Album, songs: [Song])] = []
    @State private var cachedFlipItems: [FlipItem] = []
    @State private var updateTask: Task<Void, Never>?

    // Navigation
    @State private var selectedAlbum: Album?

    // MARK: - Carousel Items

    private var flipItems: [FlipItem] { cachedFlipItems }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if flipItems.isEmpty {
                    ContentUnavailableView(
                        "No \(selectedCategory.rawValue)",
                        systemImage: selectedCategory.icon,
                        description: Text("\(selectedCategory.rawValue) will appear once ripper.db is loaded.")
                    )
                } else {
                    VStack(spacing: 0) {
                        categoryBar
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        FlipView(
                            items: flipItems,
                            centeredIndex: $centeredIndex
                        ) { index in
                            handleItemTap(at: index)
                        }
                        .frame(height: 250)
                        .clipped()
                        .id(selectedCategory)

                        centeredItemInfo
                            .padding(.top, -8)
                            .padding(.bottom, 8)

                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(height: 0.5)

                        playShuffleRow

                        ScrollView {
                            contentBelowCarousel
                                .padding(.bottom, 90)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .background {
                AmbientBackgroundView(colors: albumColors, image: centeredItemImage)
                    .animation(.easeInOut(duration: 0.5), value: displayIndex)
                    .animation(.easeInOut(duration: 0.5), value: selectedCategory)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { loadAllData() }
            .onChange(of: centeredIndex) { _, _ in debouncedUpdate() }
            .onChange(of: selectedCategory) { _, _ in
                centeredIndex = 0
                displayIndex = 0
                rebuildFlipItems()
                updateCenteredState()
            }
            .navigationDestination(item: $selectedAlbum) { album in
                AlbumDetailView(album: album)
            }
        }
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(LibraryCategory.allCases, id: \.self) { category in
                        categoryButton(category)
                            .id(category)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: selectedCategory) { _, newCategory in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    proxy.scrollTo(newCategory, anchor: .center)
                }
            }
        }
    }

    private func categoryButton(_ category: LibraryCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedCategory = category
            }
        } label: {
            Text(category.rawValue)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .matchedGeometryEffect(id: "category_indicator", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Centered Item Info

    @ViewBuilder
    private var centeredItemInfo: some View {
        switch selectedCategory {
        case .albums:
            if let album = centeredAlbum {
                VStack(spacing: 3) {
                    Text(album.name)
                        .font(.headline).fontWeight(.bold).foregroundStyle(.white)
                    Text(album.artist)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                    if let year = album.year {
                        Text(String(year))
                            .font(.caption).foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .id("album-\(displayIndex)")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: displayIndex)
            }
        case .artists:
            if artistItems.indices.contains(displayIndex) {
                VStack(spacing: 3) {
                    Text(artistItems[displayIndex].name)
                        .font(.headline).fontWeight(.bold).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .id("artist-\(displayIndex)")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: displayIndex)
            }
        case .playlists:
            if playlists.indices.contains(displayIndex) {
                let playlist = playlists[displayIndex]
                VStack(spacing: 3) {
                    Text(playlist.name)
                        .font(.headline).fontWeight(.bold).foregroundStyle(.white)
                    if let desc = playlist.description, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .id("playlist-\(displayIndex)")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: displayIndex)
            }
        }
    }

    // MARK: - Play / Shuffle Row

    @ViewBuilder
    private var playShuffleRow: some View {
        let currentTracks = allCurrentTracks
        if !currentTracks.isEmpty {
            HStack(spacing: 20) {
                Button {
                    if let first = currentTracks.first {
                        appState.play(song: first, queue: currentTracks)
                    }
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button {
                    if let random = currentTracks.randomElement() {
                        appState.playShuffled(song: random, queue: currentTracks)
                    }
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Content Below Carousel

    @ViewBuilder
    private var contentBelowCarousel: some View {
        switch selectedCategory {
        case .albums:
            albumTrackList
        case .artists:
            artistGroupedList
        case .playlists:
            playlistTrackList
        }
    }

    // MARK: - Album Track List

    private var albumTrackList: some View {
        LazyVStack(spacing: 0) {
            ForEach(tracks) { song in
                trackRow(song: song, queue: tracks)

                if song.id != tracks.last?.id {
                    Divider().background(.white.opacity(0.1)).padding(.leading, 50)
                }
            }
        }
    }

    // MARK: - Artist Grouped List

    private var artistGroupedList: some View {
        LazyVStack(spacing: 0) {
            ForEach(artistAlbumGroups, id: \.album.id) { group in
                // Album section header
                HStack(spacing: 10) {
                    if let image = group.album.coverArtImage {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.album.name)
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
                        if let year = group.album.year {
                            Text(String(year))
                                .font(.caption2).foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06))

                // Tracks under this album
                ForEach(group.songs) { song in
                    trackRow(song: song, queue: group.songs)

                    if song.id != group.songs.last?.id {
                        Divider().background(.white.opacity(0.1)).padding(.leading, 50)
                    }
                }

                // Separator between album groups
                if group.album.id != artistAlbumGroups.last?.album.id {
                    Spacer().frame(height: 12)
                }
            }
        }
    }

    // MARK: - Playlist Track List

    private var playlistTrackList: some View {
        LazyVStack(spacing: 0) {
            ForEach(tracks) { song in
                trackRow(song: song, queue: tracks)

                if song.id != tracks.last?.id {
                    Divider().background(.white.opacity(0.1)).padding(.leading, 50)
                }
            }
        }
    }

    // MARK: - Shared Track Row

    private func trackRow(song: Song, queue: [Song]) -> some View {
        Button {
            appState.play(song: song, queue: queue)
        } label: {
            HStack(spacing: 10) {
                if let num = song.trackNumber {
                    Text("\(num)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 24, alignment: .trailing)
                        .monospacedDigit()
                }

                Text(song.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(song.durationFormatted)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .monospacedDigit()
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var centeredAlbum: Album? {
        albums.indices.contains(displayIndex) ? albums[displayIndex] : nil
    }

    private var centeredItemImage: UIImage? {
        switch selectedCategory {
        case .albums:
            return centeredAlbum?.coverArtImage
        case .artists:
            guard artistItems.indices.contains(displayIndex),
                  let path = artistItems[displayIndex].coverArtFilePath else { return nil }
            return ImageCache.shared.image(forPath: path)
        case .playlists:
            guard playlists.indices.contains(displayIndex) else { return nil }
            return playlists[displayIndex].coverArtImage
        }
    }

    /// All tracks currently visible below the carousel (used for Play/Shuffle).
    private var allCurrentTracks: [Song] {
        switch selectedCategory {
        case .albums, .playlists:
            return tracks
        case .artists:
            return artistAlbumGroups.flatMap(\.songs)
        }
    }

    // MARK: - Data Loading

    private func loadAllData() {
        albums = appState.databaseManager.loadAlbums()

        // Build artist items from loaded albums (first album cover per artist)
        var seen: Set<String> = []
        var artists: [ArtistItem] = []
        for album in albums {
            if !seen.contains(album.artist) {
                seen.insert(album.artist)
                artists.append(ArtistItem(name: album.artist, coverArtFilePath: album.coverArtFilePath))
            }
        }
        artistItems = artists

        playlists = appState.databaseManager.loadPlaylists()

        rebuildFlipItems()
        displayIndex = 0
        updateCenteredState()
    }

    private func rebuildFlipItems() {
        switch selectedCategory {
        case .albums:
            cachedFlipItems = albums.map { FlipItem(id: "album-\($0.id)", coverArtFilePath: $0.coverArtFilePath) }
        case .artists:
            cachedFlipItems = artistItems.map { FlipItem(id: "artist-\($0.name)", coverArtFilePath: $0.coverArtFilePath) }
        case .playlists:
            cachedFlipItems = playlists.map { FlipItem(id: "playlist-\($0.id)", coverArtFilePath: $0.coverArtFilePath) }
        }
    }

    /// Debounce ALL updates so nothing runs during flipping
    private func debouncedUpdate() {
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            displayIndex = centeredIndex
            updateCenteredState()
        }
    }

    private func updateCenteredState() {
        switch selectedCategory {
        case .albums:
            guard let album = centeredAlbum else { tracks = []; return }
            tracks = appState.databaseManager.loadSongsForAlbum(albumId: album.id)
            updateColors(image: album.coverArtImage, cacheKey: album.spotifyId ?? "album-\(album.id)")

        case .artists:
            guard artistItems.indices.contains(displayIndex) else { artistAlbumGroups = []; return }
            let artistName = artistItems[displayIndex].name
            let artistAlbums = albums.filter { $0.artist.localizedCaseInsensitiveCompare(artistName) == .orderedSame }
            artistAlbumGroups = artistAlbums.compactMap { album in
                let allSongs = appState.databaseManager.loadSongsForAlbum(albumId: album.id)
                // Filter to only songs where the song artist or albumArtist matches
                let songs = allSongs.filter { song in
                    song.artist.localizedCaseInsensitiveCompare(artistName) == .orderedSame
                    || (song.albumArtist ?? "").localizedCaseInsensitiveCompare(artistName) == .orderedSame
                }
                // Skip albums with no matching songs
                guard !songs.isEmpty else { return nil }
                return (album: album, songs: songs)
            }
            if let firstAlbum = artistAlbums.first {
                updateColors(image: firstAlbum.coverArtImage, cacheKey: firstAlbum.spotifyId ?? "album-\(firstAlbum.id)")
            }

        case .playlists:
            guard playlists.indices.contains(displayIndex) else { tracks = []; return }
            let playlist = playlists[displayIndex]
            tracks = appState.databaseManager.loadSongsForPlaylist(playlistId: playlist.id)
            if let image = playlist.coverArtImage {
                updateColors(image: image, cacheKey: "playlist-\(playlist.id)")
            } else {
                albumColors = .placeholder
            }
        }
    }

    private func updateColors(image: UIImage?, cacheKey: String) {
        guard let image else { albumColors = .placeholder; return }
        albumColors = ColorExtractor.shared.extract(from: image, cacheKey: cacheKey)
    }

    private func handleItemTap(at index: Int) {
        switch selectedCategory {
        case .albums:
            guard albums.indices.contains(index) else { return }
            selectedAlbum = albums[index]
        case .artists:
            break
        case .playlists:
            break
        }
    }
}
