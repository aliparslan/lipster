import SwiftUI

@main
struct LipsterApp: App {
    @State private var appState = AppState()
    @State private var selectedSection: AppSection = .library
    @State private var showNowPlaying = false
    @State private var showSettings = false
    @Namespace private var nowPlayingNamespace

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedSection) {
                DiscoverView()
                    .tag(AppSection.discover)

                LibraryView()
                    .tag(AppSection.library)

                SearchView()
                    .tag(AppSection.search)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                BottomBarView(
                    selectedSection: $selectedSection,
                    showNowPlaying: $showNowPlaying,
                    nowPlayingNamespace: nowPlayingNamespace
                )
            }
            .overlay(alignment: .topTrailing) {
                gearButton
            }
            .environment(appState)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
                    .environment(appState)
                    .interactiveDismissDisabled(false)
                    .modifier(NowPlayingZoomTransitionModifier(namespace: nowPlayingNamespace))
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
                .environment(appState)
                .preferredColorScheme(.dark)
            }
        }
    }

    private var gearButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .padding(.trailing, 16)
        .padding(.top, 4)
    }
}

private struct NowPlayingZoomTransitionModifier: ViewModifier {
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: "nowPlaying", in: namespace))
        } else {
            content
        }
    }
}
