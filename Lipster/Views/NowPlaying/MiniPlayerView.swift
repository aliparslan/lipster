import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState
    @Binding var showNowPlaying: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar along top edge
            GeometryReader { geo in
                Rectangle()
                    .fill(appState.albumColors.primary)
                    .frame(width: geo.size.width * progress, height: 2)
                    .animation(.linear(duration: 0.5), value: progress)
            }
            .frame(height: 2)

            HStack(spacing: 12) {
                // Album art
                if let song = appState.currentSong, let uiImage = song.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.08))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.white.opacity(0.4))
                        }
                }

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.currentSong?.title ?? "Not Playing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(appState.currentSong?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                // Play/Pause
                Button {
                    Haptics.impact(.light)
                    appState.togglePlayPause()
                } label: {
                    Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                // Skip next
                Button {
                    Haptics.impact(.light)
                    appState.skipNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showNowPlaying = true
        }
    }

    private var progress: CGFloat {
        guard appState.duration > 0 else { return 0 }
        return CGFloat(appState.currentTime / appState.duration)
    }
}
