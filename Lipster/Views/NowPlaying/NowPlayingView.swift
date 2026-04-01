import MediaPlayer
import SwiftUI

struct NowPlayingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false
    @State private var artScale: CGFloat = 1.0
    @State private var showQueue: Bool = false
    @State private var artOffset: CGFloat = 0

    private var colors: AlbumColors {
        appState.albumColors
    }

    var body: some View {
        ZStack {
            AmbientBackgroundView(colors: colors, image: appState.currentSong?.coverArtImage, overlayOpacity: 0.3)
                .animation(.easeInOut(duration: 1.0), value: colors)

            VStack(spacing: 0) {
                Spacer().frame(height: 20)

                albumArtWithReflection
                    .padding(.horizontal, 40)

                Spacer().frame(height: 16)

                songInfo

                Spacer().frame(height: 16)

                progressScrubber
                    .padding(.horizontal, 28)

                Spacer().frame(height: 12)

                transportControls

                VolumeSliderView()
                    .frame(height: 34)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)

                Spacer()

                bottomControls

                Spacer().frame(height: 12)
            }
        }
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .onAppear {
            sliderValue = appState.currentTime
            artScale = appState.isPlaying ? 1.0 : 0.85
        }
        .onChange(of: appState.currentTime) { _, newValue in
            if !isDragging { sliderValue = newValue }
        }
        .onChange(of: appState.currentSong) { _, _ in
            sliderValue = 0
        }
        .onChange(of: appState.isPlaying) { _, playing in
            withAnimation(.easeInOut(duration: 0.4)) {
                artScale = playing ? 1.0 : 0.85
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
                .environment(appState)
        }
    }

    // MARK: - Album Art with Reflection

    private var albumArtWithReflection: some View {
        VStack(spacing: 0) {
            Group {
                if let song = appState.currentSong, let uiImage = song.coverArtImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: colors.primary.opacity(0.4), radius: 30, y: 15)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(artScale)
            .offset(x: artOffset)
            .gesture(artSwipeGesture)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: artScale)

            // Reflection
            if let song = appState.currentSong, let uiImage = song.coverArtImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .scaleEffect(x: 1, y: -1)
                    .frame(height: 60)
                    .clipped()
                    .mask(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.3)
                    .scaleEffect(artScale)
                    .offset(x: artOffset)
            }
        }
    }

    // MARK: - Art Swipe Gesture

    private var artSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    artOffset = value.translation.width * 0.5
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 80
                if value.translation.width < -threshold {
                    Haptics.impact(.medium)
                    appState.skipNext()
                } else if value.translation.width > threshold {
                    Haptics.impact(.medium)
                    appState.skipPrevious()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    artOffset = 0
                }
            }
    }

    // MARK: - Song Info

    private var songInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentSong?.title ?? "Not Playing")
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text(appState.currentSong?.artist ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Haptics.impact(.light)
                if let song = appState.currentSong {
                    appState.databaseManager.toggleLike(songId: song.id)
                }
            } label: {
                Image(systemName: isCurrentSongLiked ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(isCurrentSongLiked ? .yellow : .white.opacity(0.5))
            }
            .buttonStyle(.plain)

            Menu {
                Button { } label: { Label("Add to Playlist", systemImage: "text.badge.plus") }
                Button { } label: { Label("Share Song", systemImage: "square.and.arrow.up") }
                Button { } label: { Label("Go to Album", systemImage: "square.stack") }
                Button { } label: { Label("Go to Artist", systemImage: "person") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 28)
    }

    private var isCurrentSongLiked: Bool {
        guard let song = appState.currentSong else { return false }
        return appState.databaseManager.isLiked(songId: song.id)
    }

    // MARK: - Progress Scrubber

    private var progressScrubber: some View {
        VStack(spacing: 6) {
            Slider(
                value: $sliderValue,
                in: 0...max(appState.duration, 1),
                onEditingChanged: { editing in
                    isDragging = editing
                    if editing {
                        Haptics.selection()
                    } else {
                        Haptics.selection()
                        appState.audioPlayer.seek(to: sliderValue)
                        appState.currentTime = sliderValue
                    }
                }
            )
            .tint(colors.primary)

            HStack {
                Text(formatTime(isDragging ? sliderValue : appState.currentTime))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
                Spacer()
                Text("-\(formatTime(max(0, appState.duration - (isDragging ? sliderValue : appState.currentTime))))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 36) {
            Button {
                Haptics.impact(.medium)
                appState.skipPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }

            Button {
                Haptics.impact(.medium)
                appState.togglePlayPause()
            } label: {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }

            Button {
                Haptics.impact(.medium)
                appState.skipNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            Button {
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button {
            } label: {
                Image(systemName: "airplayaudio")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 48)
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(max(0, time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct VolumeSliderView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = true
        view.tintColor = .white
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
