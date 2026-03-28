import SwiftUI

struct AlbumsView: View {
    @Environment(AppState.self) private var appState
    @State private var albums: [Album] = []

    var body: some View {
        Group {
            if albums.isEmpty {
                ContentUnavailableView(
                    "No Albums",
                    systemImage: "square.stack",
                    description: Text("Albums will appear once ripper.db is loaded.")
                )
            } else {
                List(albums) { album in
                    NavigationLink(value: album) {
                        AlbumRow(album: album)
                    }
                    .contextMenu {
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
                .listStyle(.plain)
                .navigationDestination(for: Album.self) { album in
                    AlbumDetailView(album: album)
                }
            }
        }
        .task {
            albums = appState.databaseManager.loadAlbums()
        }
    }
}

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

struct AlbumDetailView: View {
    @Environment(AppState.self) private var appState
    let album: Album
    @State private var songs: [Song] = []

    var body: some View {
        List {
            // Album header
            VStack(spacing: 12) {
                if let uiImage = album.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 8)
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
                        if let first = songs.first {
                            appState.shuffleEnabled = true
                            appState.play(song: first, queue: songs)
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
                    if let trackNumber = song.trackNumber {
                        Text("\(trackNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.body)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
        }
    }
}
