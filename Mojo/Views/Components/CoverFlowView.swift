import SwiftUI

struct CoverFlowView: View {
    let albums: [Album]
    let onAlbumTapped: (Album) -> Void

    @State private var scrollPosition: Int?

    var body: some View {
        GeometryReader { outer in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
                        CoverFlowItem(album: album, containerWidth: outer.size.width)
                            .id(index)
                            .onTapGesture {
                                onAlbumTapped(album)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition)
            .contentMargins(.horizontal, outer.size.width / 2 - 100, for: .scrollContent)
        }
    }
}

private struct CoverFlowItem: View {
    let album: Album
    let containerWidth: CGFloat

    private let itemWidth: CGFloat = 200

    var body: some View {
        VStack(spacing: 8) {
            coverImage
                .frame(width: itemWidth, height: itemWidth)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .rotation3DEffect(
                            .degrees(phase.value * -45),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: phase.value > 0 ? .leading : .trailing,
                            perspective: 0.4
                        )
                        .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                        .opacity(phase.isIdentity ? 1.0 : 0.7)
                }

            // Reflection
            coverImage
                .frame(width: itemWidth, height: itemWidth * 0.3)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .mask(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(x: 1, y: -1)
                .offset(y: -itemWidth * 0.3)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .rotation3DEffect(
                            .degrees(phase.value * -45),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: phase.value > 0 ? .leading : .trailing,
                            perspective: 0.4
                        )
                        .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                        .opacity(phase.isIdentity ? 1.0 : 0.5)
                }

            Text(album.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(width: itemWidth)

            Text(album.artist)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: itemWidth)
        }
        .frame(width: itemWidth + 20)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let uiImage = album.coverArtImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

#Preview {
    CoverFlowView(albums: []) { _ in }
}
