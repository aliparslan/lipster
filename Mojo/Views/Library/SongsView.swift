import SwiftUI

struct SongsView: View {
    @Environment(AppState.self) private var appState
    @State private var songs: [Song] = []

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
                            SongContextMenu(song: song)
                        }
                }
                .listStyle(.plain)
            }
        }
        .task {
            songs = appState.databaseManager.loadSongs()
        }
    }
}

struct SongRow: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
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
        .padding(.vertical, 2)
    }
}

/// Reusable context menu for songs across all views
struct SongContextMenu: View {
    @Environment(AppState.self) private var appState
    let song: Song

    var body: some View {
        Button {
            appState.addToQueue(song, position: .next)
        } label: {
            Label("Play Next", systemImage: "text.insert")
        }

        Button {
            appState.addToQueue(song, position: .last)
        } label: {
            Label("Play Later", systemImage: "text.append")
        }

        Divider()

        if let album = song.album {
            Button {
                // TODO: navigate to album
            } label: {
                Label("Go to Album", systemImage: "square.stack")
            }
        }

        Button {
            // TODO: navigate to artist
        } label: {
            Label("Go to Artist", systemImage: "person")
        }
    }
}
