import SwiftUI

struct ArtistsView: View {
    @Environment(AppState.self) private var appState
    @State private var artists: [String] = []
    @State private var allSongs: [Song] = []
    @State private var artistCovers: [String: UIImage] = [:]

    var body: some View {
        Group {
            if artists.isEmpty {
                ContentUnavailableView(
                    "No Artists",
                    systemImage: "person.2",
                    description: Text("Artists will appear once ripper.db is loaded.")
                )
            } else {
                List(artists, id: \.self) { artist in
                    NavigationLink(value: artist) {
                        HStack(spacing: 12) {
                            if let cover = artistCovers[artist] {
                                Image(uiImage: cover)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(.secondary)
                                    }
                            }
                            Text(artist)
                                .font(.body)
                        }
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: String.self) { artist in
                    ArtistDetailView(artist: artist, allSongs: allSongs)
                }
            }
        }
        .task {
            allSongs = appState.databaseManager.loadSongs()
            let uniqueArtists = Set(allSongs.map { $0.artist })
            artists = uniqueArtists.sorted()

            // Load artist cover art, yielding between each to keep UI responsive
            let db = appState.databaseManager
            for artist in artists {
                if let cover = db.loadCoverForArtist(name: artist) {
                    artistCovers[artist] = cover
                }
                await Task.yield()
            }
        }
    }
}

struct ArtistDetailView: View {
    @Environment(AppState.self) private var appState
    let artist: String
    let allSongs: [Song]

    var artistSongs: [Song] {
        allSongs.filter { $0.artist == artist }
    }

    var body: some View {
        List(artistSongs) { song in
            SongRow(song: song)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.play(song: song, queue: artistSongs)
                }
                .contextMenu {
                    SongContextMenu(song: song)
                }
        }
        .listStyle(.plain)
        .navigationTitle(artist)
    }
}
