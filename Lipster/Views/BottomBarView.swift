import SwiftUI

enum AppSection: Hashable {
    case discover, library, search
}

struct BottomBarView: View {
    @Binding var selectedSection: AppSection
    @Binding var showNowPlaying: Bool
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            if appState.currentSong != nil {
                MiniPlayerView(showNowPlaying: $showNowPlaying)
            }

            HStack {
                navButton(.discover, icon: "sparkles", label: "Discover")
                navButton(.library, icon: "music.note.house", label: "Library")
                navButton(.search, icon: "magnifyingglass", label: "Search")
            }
            .padding(.top, 10)
            .padding(.bottom, 2)
        }
        .background(.ultraThinMaterial)
    }

    private func navButton(_ section: AppSection, icon: String, label: String) -> some View {
        Button {
            Haptics.impact(.light)
            selectedSection = section
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
