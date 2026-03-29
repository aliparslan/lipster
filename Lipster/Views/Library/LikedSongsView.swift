import SwiftUI

struct LikedSongsView: View {
    @Environment(AppState.self) private var appState
    @State private var songs: [Song] = []

    var body: some View {
        Group {
            if songs.isEmpty {
                ContentUnavailableView(
                    "No Liked Songs",
                    systemImage: "heart",
                    description: Text("Songs you've liked will appear here.")
                )
            } else {
                List {
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
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)

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
            }
        }
        .task {
            songs = appState.databaseManager.loadLikedSongs()
        }
    }
}
