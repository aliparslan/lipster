import Foundation

struct Folder: Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    let parentId: Int64?
}
