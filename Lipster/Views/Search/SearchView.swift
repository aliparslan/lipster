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
            ZStack {
                AmbientBackgroundView(
                    colors: appState.albumColors,
                    image: appState.currentSong?.coverArtImage
                )

                Group {
                    if searchText.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Text("Search by song title, artist, or album.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if songResults.isEmpty && albumResults.isEmpty && artistResults.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                if !artistResults.isEmpty {
                                    sectionHeader("Artists")
                                    ForEach(artistResults, id: \.self) { artist in
                                        NavigationLink(value: artist) {
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(.white.opacity(0.08))
                                                    .frame(width: 40, height: 40)
                                                    .overlay {
                                                        Text(String(artist.prefix(1)).uppercased())
                                                            .font(.headline).fontWeight(.bold)
                                                            .foregroundStyle(.white.opacity(0.6))
                                                    }
                                                Text(artist)
                                                    .font(.body).foregroundStyle(.white)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption).foregroundStyle(.white.opacity(0.3))
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                            .padding(.horizontal, 16).padding(.vertical, 2)
                                        }
                                    }
                                }

                                if !albumResults.isEmpty {
                                    sectionHeader("Albums")
                                    ForEach(albumResults) { album in
                                        NavigationLink(value: album) {
                                            HStack(spacing: 12) {
                                                if let image = album.coverArtImage {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .frame(width: 44, height: 44)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(.white.opacity(0.08))
                                                        .frame(width: 44, height: 44)
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(album.name)
                                                        .font(.subheadline).foregroundStyle(.white).lineLimit(1)
                                                    Text(album.artist)
                                                        .font(.caption).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption).foregroundStyle(.white.opacity(0.3))
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                            .padding(.horizontal, 16).padding(.vertical, 2)
                                        }
                                    }
                                }

                                if !songResults.isEmpty {
                                    sectionHeader("Songs")
                                    ForEach(songResults) { song in
                                        Button {
                                            appState.play(song: song, queue: songResults)
                                        } label: {
                                            HStack(spacing: 12) {
                                                if let image = song.coverArtImage {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .frame(width: 44, height: 44)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(.white.opacity(0.08))
                                                        .frame(width: 44, height: 44)
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(song.title)
                                                        .font(.subheadline).foregroundStyle(.white).lineLimit(1)
                                                    Text(song.artist)
                                                        .font(.caption).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                                                }
                                                Spacer()
                                                Text(song.durationFormatted)
                                                    .font(.caption).foregroundStyle(.white.opacity(0.4)).monospacedDigit()
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                            .padding(.horizontal, 16).padding(.vertical, 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white.opacity(0.4))
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
}
