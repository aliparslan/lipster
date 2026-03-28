import SwiftUI

@main
struct MojoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            TabView {
                LibraryView()
                    .safeAreaInset(edge: .bottom) {
                        if appState.currentSong != nil {
                            MiniPlayerView()
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .tabItem {
                        Label("Library", systemImage: "music.note.house")
                    }

                SearchView()
                    .safeAreaInset(edge: .bottom) {
                        if appState.currentSong != nil {
                            MiniPlayerView()
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                SettingsView()
                    .safeAreaInset(edge: .bottom) {
                        if appState.currentSong != nil {
                            MiniPlayerView()
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .environment(appState)
        }
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            List {
                Section("Playback") {
                    Toggle("Gapless Playback", isOn: .constant(true))
                    Toggle("Crossfade", isOn: .constant(false))
                    Toggle("Volume Normalization", isOn: $appState.volumeNormalizationEnabled)
                }
                Section("Library") {
                    LabeledContent("Database", value: "ripper.db")
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
