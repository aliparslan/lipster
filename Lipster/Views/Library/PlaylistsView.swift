import SwiftUI

struct PlaylistsView: View {
    @Environment(AppState.self) private var appState
    @State private var playlists: [Playlist] = []

    private var playlistPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: "music.note.list")
                    .foregroundStyle(.secondary)
            }
    }

    var body: some View {
        Group {
            if playlists.isEmpty {
                ContentUnavailableView(
                    "No Playlists",
                    systemImage: "music.note.list",
                    description: Text("Playlists will appear once ripper.db is loaded.")
                )
            } else {
                List(playlists) { playlist in
                    NavigationLink(value: playlist) {
                        HStack(spacing: 12) {
                            Group {
                                if let coverPath = playlist.coverPath,
                                   !coverPath.isEmpty,
                                   let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                    let url = docs.appendingPathComponent(coverPath)
                                    if let uiImage = ImageCache.shared.image(forPath: url.path) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        playlistPlaceholder
                                    }
                                } else {
                                    playlistPlaceholder
                                }
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name)
                                    .font(.body)
                                    .lineLimit(1)
                                if let description = playlist.description, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .contextMenu {
                        Button {
                            let songs = appState.databaseManager.loadSongsForPlaylist(playlistId: playlist.id)
                            appState.addToQueue(songs, position: .next)
                        } label: {
                            Label("Play Next", systemImage: "text.insert")
                        }

                        Button {
                            let songs = appState.databaseManager.loadSongsForPlaylist(playlistId: playlist.id)
                            appState.addToQueue(songs, position: .last)
                        } label: {
                            Label("Play Later", systemImage: "text.append")
                        }
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: Playlist.self) { playlist in
                    PlaylistDetailView(playlist: playlist)
                }
            }
        }
        .task {
            playlists = appState.databaseManager.loadPlaylists()
        }
    }
}

struct PlaylistDetailView: View {
    @Environment(AppState.self) private var appState
    let playlist: Playlist
    @State private var songs: [Song] = []

    var body: some View {
        List {
            // Playlist header with play/shuffle
            VStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .frame(width: 120, height: 120)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(playlist.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("\(songs.count) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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

            // Songs
            ForEach(songs) { song in
                SongRow(song: song)
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
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            songs = appState.databaseManager.loadSongsForPlaylist(playlistId: playlist.id)
        }
    }
}
