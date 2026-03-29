import SwiftUI

struct AlbumsView: View {
    @Environment(AppState.self) private var appState
    @State private var albums: [Album] = []
    @State private var viewMode: ViewMode = .grid

    enum ViewMode {
        case grid, list
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        Group {
            if albums.isEmpty {
                ContentUnavailableView(
                    "No Albums",
                    systemImage: "square.stack",
                    description: Text("Albums will appear once ripper.db is loaded.")
                )
            } else {
                switch viewMode {
                case .grid:
                    gridContent
                case .list:
                    listContent
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewMode = viewMode == .grid ? .list : .grid
                    }
                } label: {
                    Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .task {
            albums = appState.databaseManager.loadAlbums()
        }
        .navigationDestination(for: Album.self) { album in
            AlbumDetailView(album: album)
        }
    }

    // MARK: - Grid View

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(albums) { album in
                    NavigationLink(value: album) {
                        AlbumGridCell(album: album)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        albumContextMenu(album: album)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
    }

    // MARK: - List View

    private var listContent: some View {
        List(albums) { album in
            NavigationLink(value: album) {
                AlbumRow(album: album)
            }
            .contextMenu {
                albumContextMenu(album: album)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func albumContextMenu(album: Album) -> some View {
        Button {
            let songs = appState.databaseManager.loadSongsForAlbum(albumId: album.id)
            if let first = songs.first {
                appState.play(song: first, queue: songs)
            }
        } label: {
            Label("Play", systemImage: "play.fill")
        }

        Button {
            let songs = appState.databaseManager.loadSongsForAlbum(albumId: album.id)
            appState.addToQueue(songs, position: .next)
        } label: {
            Label("Play Next", systemImage: "text.insert")
        }

        Button {
            let songs = appState.databaseManager.loadSongsForAlbum(albumId: album.id)
            appState.addToQueue(songs, position: .last)
        } label: {
            Label("Play Later", systemImage: "text.append")
        }
    }
}

// MARK: - Album Grid Cell

struct AlbumGridCell: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let uiImage = album.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: albumShadowColor.opacity(0.35), radius: 12, y: 6)

            Text(album.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Text(album.artist)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var albumShadowColor: Color {
        guard let image = album.coverArtImage else { return .black }
        let colors = ColorExtractor.shared.extract(from: image, cacheKey: album.spotifyId ?? "album-\(album.id)")
        return colors.primary
    }
}

// MARK: - Album Row (List)

struct AlbumRow: View {
    let album: Album

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let uiImage = album.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.body)
                    .lineLimit(1)
                Text(album.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let year = album.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Album Detail View

struct AlbumDetailView: View {
    @Environment(AppState.self) private var appState
    let album: Album
    @State private var songs: [Song] = []
    @State private var albumColors: AlbumColors = .placeholder

    var body: some View {
        List {
            // Album header
            VStack(spacing: 12) {
                if let uiImage = album.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: albumColors.primary.opacity(0.5), radius: 20, y: 10)
                }

                Text(album.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(album.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let year = album.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Play / Shuffle buttons
                HStack(spacing: 16) {
                    Button {
                        if let first = songs.first {
                            appState.play(song: first, queue: songs)
                        }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)

                    Button {
                        if let randomSong = songs.randomElement() {
                            appState.playShuffled(song: randomSong, queue: songs)
                        }
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.vertical, 8)

            // Track list
            ForEach(songs) { song in
                HStack {
                    // Now playing indicator
                    if appState.currentSong?.id == song.id && appState.isPlaying {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                            .frame(width: 24)
                    } else if let trackNumber = song.trackNumber {
                        Text("\(trackNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                    } else {
                        Spacer().frame(width: 24)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.body)
                            .lineLimit(1)
                            .foregroundStyle(appState.currentSong?.id == song.id ? Color.accentColor : .primary)
                        // Only show artist if different from album artist
                        if song.artist != album.artist {
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(song.durationFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.play(song: song, queue: songs)
                }
                .contextMenu {
                    SongContextMenu(song: song)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            songs = appState.databaseManager.loadSongsForAlbum(albumId: album.id)
            if let image = album.coverArtImage {
                albumColors = ColorExtractor.shared.extract(from: image, cacheKey: album.spotifyId ?? "album-\(album.id)")
            }
        }
    }
}
