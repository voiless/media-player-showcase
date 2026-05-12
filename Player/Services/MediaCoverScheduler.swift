import Foundation

enum MediaCoverScheduler {
    static func scheduleCoverGeneration(for item: MediaItem) {
        if item.kind == .video {
            DispatchQueue.global(qos: .userInitiated).async {
                guard let coverURL = VideoThumbnailService.generateThumbnail(for: item.url, itemId: item.id) else { return }
                DispatchQueue.main.async {
                    MediaStorageService.shared.updateVideoItemCover(id: item.id, coverURL: coverURL)
                    NotificationCenter.default.post(name: MediaStorageService.mediaCoversDidUpdateNotification, object: nil)
                }
            }
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                guard let coverURL = AudioMetadataService.extractAndSaveArtwork(from: item.url, itemId: item.id) else { return }
                DispatchQueue.main.async {
                    MediaStorageService.shared.updateAudioItemCover(id: item.id, coverURL: coverURL)
                    NotificationCenter.default.post(name: MediaStorageService.mediaCoversDidUpdateNotification, object: nil)
                }
            }
        }
    }
}
