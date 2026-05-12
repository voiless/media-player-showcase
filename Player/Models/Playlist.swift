import Foundation

struct Playlist: Equatable, Codable {
    let id: String
    var name: String
    var itemIds: [String]
    var createdAt: Date
    var kind: MediaItemKind

    init(id: String, name: String, itemIds: [String], createdAt: Date, kind: MediaItemKind = .video) {
        self.id = id
        self.name = name
        self.itemIds = itemIds
        self.createdAt = createdAt
        self.kind = kind
    }

    enum CodingKeys: String, CodingKey {
        case id, name, itemIds, createdAt, kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        itemIds = try c.decode([String].self, forKey: .itemIds)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        kind = (try? c.decode(MediaItemKind.self, forKey: .kind)) ?? .video
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(itemIds, forKey: .itemIds)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(kind, forKey: .kind)
    }
}
