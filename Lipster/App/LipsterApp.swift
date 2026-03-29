import SwiftUI

@main
struct LipsterApp: App {
    @State private var appState = AppState()
    @State private var showNowPlaying = false

    var body: some Scene {
        WindowGroup {
            TabView {
                LibraryView()
                    .safeAreaInset(edge: .bottom) { miniPlayer }
                    .tabItem { Label("Library", systemImage: "music.note.house") }

                CoverFlowBrowserView()
                    .safeAreaInset(edge: .bottom) { miniPlayer }
                    .tabItem { Label("Cover Flow", systemImage: "square.stack.3d.up") }

                SearchView()
                    .safeAreaInset(edge: .bottom) { miniPlayer }
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }

                SettingsView()
                    .safeAreaInset(edge: .bottom) { miniPlayer }
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
            .environment(appState)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
                    .environment(appState)
                    .interactiveDismissDisabled(false)
            }
        }
    }

    @ViewBuilder
    private var miniPlayer: some View {
        if appState.currentSong != nil {
            MiniPlayerView(showNowPlaying: $showNowPlaying)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
