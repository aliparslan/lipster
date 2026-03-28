import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState
    @State private var showNowPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            // Album art
            Group {
                if let song = appState.currentSong, let uiImage = song.coverArtImage {
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
                                .foregroundStyle(.secondary)
                        }
                }
            }

            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.currentSong?.title ?? "Not Playing")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(appState.currentSong?.artist ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Play/Pause
            Button {
                appState.togglePlayPause()
            } label: {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }

            // Next
            Button {
                appState.skipNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.body)
                    .frame(width: 32, height: 44)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showNowPlaying = true
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environment(appState)
        }
    }
}

#Preview {
    MiniPlayerView()
        .environment(AppState())
}
