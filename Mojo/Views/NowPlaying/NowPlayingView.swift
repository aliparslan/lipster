import CoreMotion
import SwiftUI

struct NowPlayingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false
    @State private var artScale: CGFloat = 1.0
    @State private var artRotation: Double = 0
    @State private var showQueue: Bool = false

    // Ken Burns effect state
    @State private var kenBurnsScale: CGFloat = 1.0
    @State private var kenBurnsOffsetX: CGFloat = 0
    @State private var kenBurnsOffsetY: CGFloat = 0
    @State private var kenBurnsPhase: Int = 0

    // Parallax via CoreMotion
    @State private var motionOffsetX: CGFloat = 0
    @State private var motionOffsetY: CGFloat = 0
    @StateObject private var motionManager = MotionManagerBridge()

    private var colors: AlbumColors {
        appState.albumColors
    }

    var body: some View {
        ZStack {
            // Ambient color background
            ambientBackground

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(.white.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                Spacer()

                // Album art with Ken Burns + parallax
                albumArt
                    .padding(.horizontal, 40)

                Spacer().frame(height: 36)

                // Song info
                songInfo

                Spacer().frame(height: 28)

                // Progress scrubber
                progressScrubber
                    .padding(.horizontal, 28)

                Spacer().frame(height: 20)

                // Transport controls
                transportControls

                Spacer().frame(height: 16)

                // Bottom row (queue button, etc.)
                bottomControls

                Spacer().frame(height: 20)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: appState.currentTime) { _, newValue in
            if !isDragging {
                sliderValue = newValue
            }
        }
        .onChange(of: appState.isPlaying) { _, playing in
            withAnimation(.easeInOut(duration: 0.4)) {
                artScale = playing ? 1.0 : 0.85
            }
            if playing {
                startKenBurnsAnimation()
            }
        }
        .onChange(of: appState.currentSong?.id) { _, _ in
            // Reset and restart Ken Burns when song changes
            resetKenBurns()
            if appState.isPlaying {
                startKenBurnsAnimation()
            }
        }
        .onAppear {
            motionManager.start()
            if appState.isPlaying {
                startKenBurnsAnimation()
            }
        }
        .onDisappear {
            motionManager.stop()
        }
        .onChange(of: motionManager.pitch) { _, newPitch in
            withAnimation(.interpolatingSpring(stiffness: 50, damping: 10)) {
                motionOffsetY = CGFloat(newPitch) * 8
            }
        }
        .onChange(of: motionManager.roll) { _, newRoll in
            withAnimation(.interpolatingSpring(stiffness: 50, damping: 10)) {
                motionOffsetX = CGFloat(newRoll) * 8
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
                .environment(appState)
        }
    }

    // MARK: - Ken Burns Animation

    private func startKenBurnsAnimation() {
        advanceKenBurns()
    }

    private func resetKenBurns() {
        kenBurnsScale = 1.0
        kenBurnsOffsetX = 0
        kenBurnsOffsetY = 0
        kenBurnsPhase = 0
    }

    private func advanceKenBurns() {
        let phases: [(scale: CGFloat, x: CGFloat, y: CGFloat)] = [
            (1.08, 6, 4),
            (1.12, -5, 6),
            (1.06, -4, -5),
            (1.10, 5, -3),
        ]

        let phase = phases[kenBurnsPhase % phases.count]

        withAnimation(.easeInOut(duration: 8.0)) {
            kenBurnsScale = phase.scale
            kenBurnsOffsetX = phase.x
            kenBurnsOffsetY = phase.y
        }

        kenBurnsPhase += 1

        // Schedule next phase
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            guard appState.isPlaying else { return }
            advanceKenBurns()
        }
    }

    // MARK: - Ambient Background

    private var ambientBackground: some View {
        ZStack {
            // Base gradient from album colors
            LinearGradient(
                colors: [colors.primary, colors.secondary, colors.tertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle animated mesh effect
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

            // Dark overlay for readability
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
                    .scaleEffect(kenBurnsScale)
                    .offset(x: kenBurnsOffsetX + motionOffsetX,
                            y: kenBurnsOffsetY + motionOffsetY)
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
            // Shuffle
            Button {
                appState.shuffleEnabled.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(appState.shuffleEnabled ? .white : .white.opacity(0.35))
            }

            // Previous
            Button {
                appState.skipPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }

            // Play/Pause
            Button {
                appState.togglePlayPause()
            } label: {
                Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }

            // Next
            Button {
                appState.skipNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }

            // Repeat
            Button {
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

// MARK: - CoreMotion Bridge for Parallax

/// ObservableObject bridge for CoreMotion device motion data.
/// Provides pitch and roll values for parallax effect on album art.
final class MotionManagerBridge: ObservableObject {
    private let manager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

#Preview {
    NowPlayingView()
        .environment(AppState())
}
