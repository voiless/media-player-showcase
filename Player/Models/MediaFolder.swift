import Foundation

struct MediaFolder: Equatable, Codable {
    let id: String
    var name: String
    var itemIds: [String]
}
