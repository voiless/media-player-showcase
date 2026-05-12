import Foundation

enum MediaItemKind: String, Codable {
    case audio
    case video
}

enum MediaItemStatus: String, Codable {
    case processing
    case ready
    case error
}

/// Состояние фоновой подготовки MP4 для PiP (отдельно от «можно ли смотреть»).
enum PipPreparationState: String, Codable {
    case notApplicable
    case pending
    case ready
    case failed
}

struct MediaItem: Equatable, Codable {
    let id: String
    let url: URL
    let kind: MediaItemKind
    var title: String
    var author: String?
    var coverImageURL: URL?
    var duration: TimeInterval
    var status: MediaItemStatus = .ready
    var pipPreparation: PipPreparationState = .notApplicable

    /// Строка для UI: непустой `title`, иначе имя файла без расширения
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return url.deletingPathExtension().lastPathComponent
    }
}
