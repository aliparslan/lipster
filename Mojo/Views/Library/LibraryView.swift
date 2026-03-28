import SwiftUI

struct LibraryView: View {
    @State private var selectedTab: LibraryTab = .songs
    @Namespace private var namespace

    enum LibraryTab: String, CaseIterable {
        case songs = "Songs"
        case albums = "Albums"
        case artists = "Artists"
        case playlists = "Playlists"

        var icon: String {
            switch self {
            case .songs: "music.note"
            case .albums: "square.stack"
            case .artists: "person.2"
            case .playlists: "music.note.list"
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
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(tab.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : .secondary)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .matchedGeometryEffect(id: "xmb_indicator", in: namespace)
                }
            }
            .background {
                if !isSelected {
                    Capsule()
                        .fill(Color(.systemGray6))
                }
            }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibraryView()
        .environment(AppState())
}
