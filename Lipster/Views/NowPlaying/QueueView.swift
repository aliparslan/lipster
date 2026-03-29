import SwiftUI

struct QueueView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Now Playing
                if let song = appState.currentSong {
                    Section("Now Playing") {
                        QueueSongRow(song: song, isPlaying: true)
                    }
                }

                // Up Next
                let upcoming = appState.upNext
                if !upcoming.isEmpty {
                    Section("Up Next — \(upcoming.count) songs") {
                        ForEach(Array(upcoming.enumerated()), id: \.offset) { offset, song in
                            QueueSongRow(song: song, isPlaying: false)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    let actualIndex = appState.queueIndex + 1 + offset
                                    appState.playAtIndex(actualIndex)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        let actualIndex = appState.queueIndex + 1 + offset
                                        appState.removeFromQueue(at: actualIndex)
                                    } label: {
                                        Label("Remove", systemImage: "minus.circle")
                                    }
                                }
                        }
                        .onMove { source, destination in
                            let offset = appState.queueIndex + 1
                            let from = IndexSet(source.map { $0 + offset })
                            appState.moveInQueue(from: from, to: destination + offset)
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "Queue Empty",
                            systemImage: "list.bullet",
                            description: Text("Songs will appear here as you play music.")
                        )
                    }
                }

                // History
                if !appState.history.isEmpty {
                    Section("History") {
                        ForEach(Array(appState.history.suffix(20).reversed().enumerated()), id: \.offset) { _, song in
                            QueueSongRow(song: song, isPlaying: false)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    appState.play(song: song, queue: appState.queue)
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QueueSongRow: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let uiImage = song.coverArtImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(isPlaying ? .semibold : .regular)
                    .foregroundStyle(isPlaying ? Color.accentColor : .primary)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isPlaying {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.variableColor.iterative, isActive: true)
            } else {
                Text(song.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

#Preview {
    QueueView()
        .environment(AppState())
}
