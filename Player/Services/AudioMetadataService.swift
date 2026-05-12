import AVFoundation
import Foundation
import UIKit

enum AudioMetadataService {
    static let coverSize = CGSize(width: 300, height: 300)

    static func loadTitleAndArtist(from url: URL) -> (title: String, artist: String?) {
        let asset = AVURLAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist: String?
        let titleItems = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common)
        if let item = titleItems.first, let value = item.value as? String, !value.isEmpty {
            title = value
        }
        let artistItems = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common)
        if let item = artistItems.first, let value = item.value as? String, !value.isEmpty {
            artist = value
        }
        return (title, artist)
    }

    static func extractArtwork(from url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let items = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: AVMetadataKeySpace.common)
        guard let item = items.first else { return nil }
        var imageData: Data?
        if let data = item.value as? Data {
            imageData = data
        } else if let dict = item.value as? [String: Any], let data = dict["data"] as? Data {
            imageData = data
        } else if let nsData = item.dataValue {
            imageData = nsData as Data
        }
        guard let data = imageData, let image = UIImage(data: data) else { return nil }
        return image
    }

    static func extractAndSaveArtwork(from url: URL, itemId: String) -> URL? {
        guard let image = extractArtwork(from: url) else { return nil }
        return MediaCoverCache.saveImage(image, itemId: itemId, kind: "audio", size: coverSize)
    }
}
