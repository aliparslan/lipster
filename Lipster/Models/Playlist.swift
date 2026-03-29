import Foundation

struct Playlist: Identifiable, Hashable, Sendable {
    let id: Int64
    let spotifyId: String?
    let name: String
    let description: String?
    let coverPath: String?
    let folderId: Int64?
}
