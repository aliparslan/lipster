import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var songResults: [Song] = []
    @State private var albumResults: [Album] = []
    @State private var artistResults: [String] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("Search by song title, artist, or album.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if songResults.isEmpty && albumResults.isEmpty && artistResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        // Artists section
                        if !artistResults.isEmpty {
                            Section("Artists") {
                                ForEach(artistResults, id: \.self) { artist in
                                    NavigationLink(value: artist) {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.purple.opacity(0.6), .blue.opacity(0.4)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 40, height: 40)
                                                .overlay {
                                                    Text(String(artist.prefix(1)).uppercased())
                                                        .font(.headline)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(.white)
                                                }
                                            Text(artist)
                                                .font(.body)
                                        }
                                    }
                                }
                            }
                        }

                        // Albums section
                        if !albumResults.isEmpty {
                            Section("Albums") {
                                ForEach(albumResults) { album in
                                    NavigationLink(value: album) {
                                        AlbumRow(album: album)
                                    }
                                }
                            }
                        }

                        // Songs section
                        if !songResults.isEmpty {
                            Section("Songs") {
                                ForEach(songResults) { song in
                                    SongRow(song: song)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            appState.play(song: song, queue: songResults)
                                        }
                                        .contextMenu {
                                            SongContextMenu(song: song)
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Songs, artists, albums")
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                if newValue.count >= 1 {
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        let db = appState.databaseManager
                        songResults = db.searchSongs(query: newValue)
                        albumResults = db.searchAlbums(query: newValue)
                        artistResults = db.searchArtists(query: newValue)
                    }
                } else {
                    songResults = []
                    albumResults = []
                    artistResults = []
                }
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
            }
            .navigationDestination(for: String.self) { artist in
                ArtistDetailView(artist: artist, allSongs: appState.databaseManager.loadSongs())
            }
        }
    }
}

#Preview {
    SearchView()
        .environment(AppState())
}
