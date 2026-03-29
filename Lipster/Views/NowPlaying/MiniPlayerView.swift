import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var appState
    @Binding var showNowPlaying: Bool
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar at top
            GeometryReader { geo in
                let progress = appState.duration > 0
                    ? appState.currentTime / appState.duration
                    : 0
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
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: appState.albumColors.primary.opacity(0.4), radius: 6, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
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
                    Haptics.impact(.light)
                    appState.togglePlayPause()
                } label: {
                    Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                }

                // Next
                Button {
                    Haptics.impact(.light)
                    appState.skipNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .foregroundStyle(.primary)
        .background {
            LinearGradient(
                colors: [appState.albumColors.primary.opacity(0.3), appState.albumColors.secondary.opacity(0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .offset(x: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Only track horizontal movement
                    if abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 60
                    if value.translation.width < -threshold {
                        // Swipe left → skip next
                        Haptics.impact(.medium)
                        appState.skipNext()
                    } else if value.translation.width > threshold {
                        // Swipe right → skip previous
                        Haptics.impact(.medium)
                        appState.skipPrevious()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showNowPlaying = true
        }
    }
}
