import SwiftUI

struct SongsView: View {
    @Environment(AppState.self) private var appState
    @State private var songs: [Song] = []
    @State private var navigateToAlbum: Album?
    @State private var navigateToArtist: String?

    var body: some View {
        Group {
            if songs.isEmpty {
                ContentUnavailableView(
                    "No Songs",
                    systemImage: "music.note",
                    description: Text("Add ripper.db to the app's Documents folder via Files.")
                )
            } else {
                List(songs) { song in
                    SongRow(song: song)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.play(song: song, queue: songs)
                        }
                        .contextMenu {
                            SongContextMenu(
                                song: song,
                                onGoToAlbum: { album in navigateToAlbum = album },
                                onGoToArtist: { artist in navigateToArtist = artist }
                            )
                        }
                }
                .listStyle(.plain)
            }
        }
        .task {
            songs = appState.databaseManager.loadSongs()
        }
        .navigationDestination(item: $navigateToAlbum) { album in
            AlbumDetailView(album: album)
        }
        .navigationDestination(item: $navigateToArtist) { artist in
            ArtistDetailView(artist: artist, allSongs: songs)
        }
    }
}

struct SongRow: View {
    @Environment(AppState.self) private var appState
    let song: Song

    private var isCurrentSong: Bool {
        appState.currentSong?.id == song.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // Album art with now-playing overlay
            ZStack {
                if let uiImage = song.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }

                // Now playing overlay
                if isCurrentSong && appState.isPlaying {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.black.opacity(0.4))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "waveform")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .symbolEffect(.variableColor.iterative, isActive: true)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(isCurrentSong ? Color.accentColor : .primary)
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
        .padding(.vertical, 2)
    }
}

/// Reusable context menu for songs across all views
struct SongContextMenu: View {
    @Environment(AppState.self) private var appState
    let song: Song
    var onGoToAlbum: ((Album) -> Void)?
    var onGoToArtist: ((String) -> Void)?

    var body: some View {
        Button {
            appState.databaseManager.toggleLike(songId: song.id)
        } label: {
            let isLiked = appState.databaseManager.isLiked(songId: song.id)
            Label(isLiked ? "Unlike" : "Like", systemImage: isLiked ? "heart.fill" : "heart")
        }

        Button {
            Haptics.impact(.light)
            appState.addToQueue(song, position: .next)
        } label: {
            Label("Play Next", systemImage: "text.insert")
        }

        Button {
            Haptics.impact(.light)
            appState.addToQueue(song, position: .last)
        } label: {
            Label("Play Later", systemImage: "text.append")
        }

        Divider()

        if let albumName = song.album, let onGoToAlbum {
            Button {
                if let album = appState.databaseManager.findAlbum(name: albumName, artist: song.albumArtist ?? song.artist) {
                    onGoToAlbum(album)
                }
            } label: {
                Label("Go to Album", systemImage: "square.stack")
            }
        }

        if let onGoToArtist {
            Button {
                onGoToArtist(song.artist)
            } label: {
                Label("Go to Artist", systemImage: "person")
            }
        }
    }
}
