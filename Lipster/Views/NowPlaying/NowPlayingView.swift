import MediaPlayer
import SwiftUI

struct NowPlayingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false
    @State private var showQueue: Bool = false
    @State private var artScale: CGFloat = 1.0
    @State private var artSwipeOffset: CGFloat = 0
    @State private var skipDirection: Edge = .trailing

    private var colors: AlbumColors {
        appState.albumColors
    }

    var body: some View {
        ZStack {
            ambientBackground

            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // Album art — swipeable
                albumArt
                    .padding(.horizontal, 28)

                Spacer().frame(minHeight: 24, maxHeight: 36)

                // Song info, scrubber, transport, volume, bottom
                VStack(spacing: 0) {
                    songInfoRow
                        .padding(.horizontal, 28)

                    progressScrubber
                        .padding(.horizontal, 28)
                        .padding(.top, 20)

                    transportControls
                        .padding(.top, 18)

                    volumeSlider
                        .padding(.horizontal, 28)
                        .padding(.top, 14)

                    bottomControls
                        .padding(.horizontal, 48)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            sliderValue = appState.currentTime
            artScale = appState.isPlaying ? 1.0 : 0.85
        }
        .onChange(of: appState.currentTime) { _, newValue in
            if !isDragging {
                sliderValue = newValue
            }
        }
        .onChange(of: appState.currentSong) { _, _ in
            sliderValue = 0
        }
        .onChange(of: appState.isPlaying) { _, playing in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                artScale = playing ? 1.0 : 0.85
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
                .environment(appState)
        }
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        ZStack {
            LinearGradient(
                colors: [colors.primary, colors.secondary, colors.tertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [colors.primary.opacity(0.6), .clear],
                center: .topLeading,
                startRadius: 50,
                endRadius: 400
            )

            RadialGradient(
                colors: [colors.secondary.opacity(0.4), .clear],
                center: .bottomTrailing,
                startRadius: 50,
                endRadius: 400
            )

            Color.black.opacity(0.3)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: colors)
    }

    // MARK: - Album Art

    private var albumArt: some View {
        Group {
            if let song = appState.currentSong, let uiImage = song.coverArtImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: colors.primary.opacity(0.4), radius: 30, y: 15)
                    .id(song.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: skipDirection).combined(with: .opacity),
                        removal: .move(edge: skipDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                    ))
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
        .scaleEffect(artScale)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: artScale)
        .offset(x: artSwipeOffset)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        artSwipeOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 80
                    if value.translation.width < -threshold || value.predictedEndTranslation.width < -200 {
                        Haptics.impact(.medium)
                        skipDirection = .trailing
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            artSwipeOffset = 0
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.skipNext()
                        }
                    } else if value.translation.width > threshold || value.predictedEndTranslation.width > 200 {
                        Haptics.impact(.medium)
                        skipDirection = .leading
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            artSwipeOffset = 0
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.skipPrevious()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            artSwipeOffset = 0
                        }
                    }
                }
        )
    }

    // MARK: - Song Info Row

    private var songInfoRow: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentSong?.title ?? "Not Playing")
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text(appState.currentSong?.artist ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                // Star / favorite button
                Button {
                    Haptics.impact(.light)
                    if let song = appState.currentSong {
                        appState.databaseManager.toggleLike(songId: song.id)
                    }
                } label: {
                    Image(systemName: isCurrentSongLiked ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(isCurrentSongLiked ? .yellow : .white.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace))
                }

                // Context menu
                Menu {
                    Button { } label: {
                        Label("Add to Playlist", systemImage: "text.badge.plus")
                    }
                    Button { } label: {
                        Label("Share Song", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button { } label: {
                        Label("Go to Album", systemImage: "square.stack")
                    }
                    Button { } label: {
                        Label("Go to Artist", systemImage: "person")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.1), in: Circle())
                }
            }
        }
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
                in: 0...max(appState.duration, 1)
            ) {
                Text("Progress")
            } onEditingChanged: { editing in
                isDragging = editing
                if editing {
                    Haptics.selection()
                } else {
                    Haptics.selection()
                    appState.audioPlayer.seek(to: sliderValue)
                    appState.currentTime = sliderValue
                }
            }
            .sliderThumbVisibility(.hidden)
            .tint(colors.primary)

            HStack {
                Text(formatTime(isDragging ? sliderValue : appState.currentTime))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
                Spacer()
                Text("-\(formatTime(max(0, appState.duration - (isDragging ? sliderValue : appState.currentTime))))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack {
            Spacer()

            Button {
                Haptics.impact(.medium)
                skipDirection = .leading
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.skipPrevious()
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 56)
            }

            Spacer()

            Button {
                Haptics.impact(.medium)
                appState.togglePlayPause()
            } label: {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 64)
                    .contentTransition(.symbolEffect(.replace))
            }

            Spacer()

            Button {
                Haptics.impact(.medium)
                skipDirection = .trailing
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.skipNext()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 56)
            }

            Spacer()
        }
    }

    // MARK: - Volume Slider

    private var volumeSlider: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))

            SystemVolumeSlider()
                .frame(height: 34)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            Button { } label: {
                Image(systemName: "quote.bubble")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button { } label: {
                Image(systemName: "airplayaudio")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 44, height: 44)
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(max(0, time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NowPlayingView()
        .environment(AppState())
}
