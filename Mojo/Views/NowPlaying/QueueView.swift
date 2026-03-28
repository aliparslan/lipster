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
                        ForEach(Array(upcoming.enumerated()), id: \.element.id) { offset, song in
                            QueueSongRow(song: song, isPlaying: false)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Jump to this song in queue
                                    let actualIndex = appState.queueIndex + 1 + offset
                                    if actualIndex < appState.queue.count {
                                        appState.play(song: appState.queue[actualIndex])
                                        appState.queueIndex = actualIndex
                                    }
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
                        ForEach(appState.history.suffix(20).reversed()) { song in
                            QueueSongRow(song: song, isPlaying: false)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    appState.play(song: song)
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
