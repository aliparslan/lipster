import SwiftUI

struct CoverFlowBrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var albums: [Album] = []
    @State private var selectedAlbum: Album?
    @State private var centeredAlbumIndex: Int = 0
    @State private var tracks: [Song] = []
    @State private var albumColors: AlbumColors = .placeholder

    private var centeredAlbum: Album? {
        albums.indices.contains(centeredAlbumIndex) ? albums[centeredAlbumIndex] : nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if albums.isEmpty {
                    ContentUnavailableView(
                        "No Albums",
                        systemImage: "square.stack.3d.up",
                        description: Text("Albums will appear once ripper.db is loaded.")
                    )
                } else {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 16)

                        // Cover Flow carousel with reflections
                        CoverFlowView(
                            albums: albums,
                            centeredIndex: $centeredAlbumIndex
                        ) { album in
                            selectedAlbum = album
                        }
                        .frame(height: 250)
                        .clipped()

                        // Album info — overlaps tail of reflection
                        albumInfo
                            .padding(.top, -8)
                            .padding(.bottom, 8)

                        // Divider
                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(height: 0.5)

                        // Play / Shuffle row
                        if !tracks.isEmpty {
                            HStack(spacing: 20) {
                                Button {
                                    if let first = tracks.first {
                                        appState.play(song: first, queue: tracks)
                                    }
                                } label: {
                                    Label("Play", systemImage: "play.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    if let randomSong = tracks.randomElement() {
                                        appState.playShuffled(song: randomSong, queue: tracks)
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

                        // Track list for selected album
                        trackList
                            .padding(.bottom, appState.currentSong != nil ? 70 : 0)
                    }
                }
            }
            .background { ps3Background }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                let loaded = appState.databaseManager.loadAlbums()
                albums = loaded
                if let first = loaded.first {
                    tracks = appState.databaseManager.loadSongsForAlbum(albumId: first.id)
                    if let image = first.coverArtImage {
                        albumColors = ColorExtractor.shared.extract(
                            from: image,
                            cacheKey: first.spotifyId ?? "album-\(first.id)"
                        )
                    }
                }
            }
            .onChange(of: centeredAlbumIndex) { _, _ in
                loadTracks()
                updateColors()
            }
            .navigationDestination(item: $selectedAlbum) { album in
                AlbumDetailView(album: album)
            }
        }
    }

    // MARK: - Album Info

    @ViewBuilder
    private var albumInfo: some View {
        if let album = centeredAlbum {
            VStack(spacing: 3) {
                Text(album.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(album.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                if let year = album.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .id(centeredAlbumIndex)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: centeredAlbumIndex)
        }
    }

    // MARK: - Track List

    private var trackList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(tracks) { song in
                    Button {
                        appState.play(song: song, queue: tracks)
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

                    if song.id != tracks.last?.id {
                        Divider()
                            .background(.white.opacity(0.1))
                            .padding(.leading, 50)
                    }
                }
            }
        }
    }

    // MARK: - Load Tracks

    private func loadTracks() {
        guard let album = centeredAlbum else {
            tracks = []
            return
        }
        tracks = appState.databaseManager.loadSongsForAlbum(albumId: album.id)
    }

    // MARK: - Update Colors (cached, not computed in body)

    private func updateColors() {
        guard let album = centeredAlbum,
              let image = album.coverArtImage else {
            albumColors = .placeholder
            return
        }
        albumColors = ColorExtractor.shared.extract(
            from: image,
            cacheKey: album.spotifyId ?? "album-\(album.id)"
        )
    }

    // MARK: - PS3-Inspired Background

    private var ps3Background: some View {
        ZStack {
            Color.black

            if let album = centeredAlbum,
               let image = album.coverArtImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 80)
                    .opacity(0.2)
                    .scaleEffect(1.5)
                    .clipped()
                    .id(centeredAlbumIndex)
                    .transition(.opacity)
            }

            LinearGradient(
                colors: [
                    albumColors.primary.opacity(0.25),
                    .clear,
                    albumColors.secondary.opacity(0.15),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [albumColors.primary.opacity(0.12), .clear],
                center: .init(x: 0.5, y: 0.3),
                startRadius: 10,
                endRadius: 350
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: centeredAlbumIndex)
    }
}
