import MediaPlayer
import SwiftUI

struct NowPlayingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false
    @State private var artScale: CGFloat = 1.0
    @State private var showQueue: Bool = false

    private var colors: AlbumColors {
        appState.albumColors
    }

    var body: some View {
        ZStack {
            ambientBackground

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(.white.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                Spacer()

                // Album art
                albumArt
                    .padding(.horizontal, 28)

                Spacer().frame(height: 36)

                songInfo

                Spacer().frame(height: 28)

                progressScrubber
                    .padding(.horizontal, 28)

                Spacer().frame(height: 20)

                transportControls

                VolumeSliderView()
                    .frame(height: 34)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                Spacer().frame(height: 16)

                bottomControls

                Spacer().frame(height: 20)
            }
        }
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            // Sync slider to current playback position to prevent jump
            sliderValue = appState.currentTime
            artScale = appState.isPlaying ? 1.0 : 0.85
        }
        .onChange(of: appState.currentTime) { _, newValue in
            if !isDragging {
                sliderValue = newValue
            }
        }
        .onChange(of: appState.currentSong) { _, _ in
            // Reset slider when song changes
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

            Color.black.opacity(0.15)
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
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
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
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: artScale)
    }

    // MARK: - Song Info

    private var songInfo: some View {
        VStack(spacing: 6) {
            Text(appState.currentSong?.title ?? "Not Playing")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .foregroundStyle(.white)

            Text(appState.currentSong?.artist ?? "")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            if let album = appState.currentSong?.album {
                Text(album)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Progress Scrubber

    private var progressScrubber: some View {
        VStack(spacing: 6) {
            Slider(
                value: $sliderValue,
                in: 0...max(appState.duration, 1),
                onEditingChanged: { editing in
                    isDragging = editing
                    if !editing {
                        appState.audioPlayer.seek(to: sliderValue)
                        appState.currentTime = sliderValue
                    }
                }
            )
            .tint(.white)

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
                Haptics.impact(.light)
                appState.shuffleEnabled.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(appState.shuffleEnabled ? .white : .white.opacity(0.35))
            }

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
                Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
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

            Button {
                Haptics.impact(.light)
                appState.repeatMode = appState.repeatMode.next
            } label: {
                Image(systemName: appState.repeatMode.systemImage)
                    .font(.title3)
                    .foregroundStyle(appState.repeatMode == .off ? .white.opacity(0.35) : .white)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            Menu {
                Button("15 minutes") { appState.setSleepTimer(minutes: 15) }
                Button("30 minutes") { appState.setSleepTimer(minutes: 30) }
                Button("45 minutes") { appState.setSleepTimer(minutes: 45) }
                Button("60 minutes") { appState.setSleepTimer(minutes: 60) }
                if appState.sleepTimerMinutes != nil {
                    Button("Cancel Timer", role: .destructive) { appState.cancelSleepTimer() }
                }
            } label: {
                Image(systemName: appState.sleepTimerMinutes != nil ? "moon.fill" : "moon.zzz")
                    .font(.title3)
                    .foregroundStyle(appState.sleepTimerMinutes != nil ? .white : .white.opacity(0.35))
            }

            Spacer()

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 28)
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

#Preview {
    NowPlayingView()
        .environment(AppState())
}
