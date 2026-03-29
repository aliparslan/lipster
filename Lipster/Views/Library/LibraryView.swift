import SwiftUI

struct LibraryView: View {
    @State private var selectedTab: LibraryTab = .songs
    @Namespace private var namespace

    enum LibraryTab: String, CaseIterable {
        case songs = "Songs"
        case albums = "Albums"
        case artists = "Artists"
        case playlists = "Playlists"
        case liked = "Liked"

        var icon: String {
            switch self {
            case .songs: "music.note"
            case .albums: "square.stack"
            case .artists: "person.2"
            case .playlists: "music.note.list"
            case .liked: "heart.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // XMB-style horizontal category selector
                xmbCategorySelector
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Content
                switch selectedTab {
                case .songs:
                    SongsView()
                        .transition(.opacity)
                case .albums:
                    AlbumsView()
                        .transition(.opacity)
                case .artists:
                    ArtistsView()
                        .transition(.opacity)
                case .playlists:
                    PlaylistsView()
                        .transition(.opacity)
                case .liked:
                    LikedSongsView()
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
            .navigationTitle("Library")
        }
    }

    // MARK: - XMB Category Selector

    private var xmbCategorySelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        xmbCategoryButton(tab: tab)
                            .id(tab)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: selectedTab) { _, newTab in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    proxy.scrollTo(newTab, anchor: .center)
                }
            }
        }
    }

    private func xmbCategoryButton(tab: LibraryTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: tab.icon)
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Text(tab.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .padding(.horizontal, isSelected ? 14 : 10)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .background {
                if isSelected {
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .matchedGeometryEffect(id: "xmb_indicator", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibraryView()
        .environment(AppState())
}
