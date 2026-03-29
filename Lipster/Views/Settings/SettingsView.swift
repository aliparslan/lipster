import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            List {
                Section("Playback") {
                    HStack {
                        Text("Gapless Playback")
                        Spacer()
                        Text("On")
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Volume Normalization", isOn: $appState.volumeNormalizationEnabled)
                }
                Section("Library") {
                    LabeledContent("Songs", value: "\(appState.databaseManager.songCount())")
                    LabeledContent("Albums", value: "\(appState.databaseManager.albumCount())")
                    LabeledContent("Artists", value: "\(appState.databaseManager.artistCount())")
                    LabeledContent("Database", value: "ripper.db")
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Color(.systemBackground)
                    if let song = appState.currentSong, let image = song.coverArtImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 100)
                            .opacity(0.08)
                            .scaleEffect(1.5)
                            .ignoresSafeArea()
                    }
                }
            }
        }
    }
}
