import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        List {
            Section("Playback") {
                HStack {
                    Text("Gapless Playback")
                    Spacer()
                    Text("On")
                        .foregroundStyle(.white.opacity(0.5))
                }
                Toggle("Volume Normalization", isOn: $appState.volumeNormalizationEnabled)
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("Library") {
                LabeledContent("Songs", value: "\(appState.databaseManager.songCount())")
                LabeledContent("Albums", value: "\(appState.databaseManager.albumCount())")
                LabeledContent("Artists", value: "\(appState.databaseManager.artistCount())")
                LabeledContent("Database", value: "ripper.db")
            }
            .listRowBackground(Color.white.opacity(0.06))

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
            }
            .listRowBackground(Color.white.opacity(0.06))
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background {
            AmbientBackgroundView(
                colors: appState.albumColors,
                image: appState.currentSong?.coverArtImage
            )
        }
    }
}
