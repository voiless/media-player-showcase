import Foundation

struct Album: Equatable, Codable {
    let id: String
    var name: String
    var itemIds: [String]
}
