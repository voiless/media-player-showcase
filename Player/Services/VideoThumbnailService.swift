import AVFoundation
import Foundation
import MobileVLCKit
import UIKit

enum VideoThumbnailService {
    static let thumbnailSize = CGSize(width: 300, height: 300)

    private static let avThumbnailExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mpeg4", "m4p", "3gp"]

    static func generateThumbnail(for videoURL: URL, itemId: String) -> URL? {
        if Self.avThumbnailExtensions.contains((videoURL.pathExtension as NSString).lowercased) {
            if let url = generateWithAVFoundation(videoURL: videoURL, itemId: itemId) {
                return url
            }
        }
        return generateWithVLC(videoURL: videoURL, itemId: itemId) ?? generateWithAVFoundation(videoURL: videoURL, itemId: itemId)
    }

    private static func generateWithAVFoundation(videoURL: URL, itemId: String) -> URL? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: thumbnailSize.width * 2, height: thumbnailSize.height * 2)
        let time = CMTime(value: 0, timescale: 1)
        var actualTime: CMTime = .zero
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: &actualTime) else { return nil }
        let image = UIImage(cgImage: cgImage)
        return MediaCoverCache.saveImage(image, itemId: itemId, kind: "video", size: thumbnailSize)
    }

    private static func generateWithVLC(videoURL: URL, itemId: String) -> URL? {
        let media = VLCMedia(url: videoURL)
        let semaphore = DispatchSemaphore(value: 0)
        var resultImage: CGImage?
        let delegate = VLCThumbnailDelegate(semaphore: semaphore) { resultImage = $0 }
        let thumbnailer = VLCMediaThumbnailer(media: media, andDelegate: delegate)
        thumbnailer.thumbnailWidth = thumbnailSize.width * 2
        thumbnailer.thumbnailHeight = thumbnailSize.height * 2
        thumbnailer.snapshotPosition = 0.1
        thumbnailer.fetchThumbnail()
        _ = semaphore.wait(timeout: .now() + 15)
        guard let cgImage = resultImage else { return nil }
        let image = UIImage(cgImage: cgImage)
        return MediaCoverCache.saveImage(image, itemId: itemId, kind: "video", size: thumbnailSize)
    }
}

private final class VLCThumbnailDelegate: NSObject, VLCMediaThumbnailerDelegate {
    private let semaphore: DispatchSemaphore
    private let onSuccess: (CGImage) -> Void

    init(semaphore: DispatchSemaphore, onSuccess: @escaping (CGImage) -> Void) {
        self.semaphore = semaphore
        self.onSuccess = onSuccess
    }

    func mediaThumbnailer(_ mediaThumbnailer: VLCMediaThumbnailer, didFinishThumbnail thumbnail: CGImage) {
        onSuccess(thumbnail)
        semaphore.signal()
    }

    func mediaThumbnailerDidTimeOut(_ mediaThumbnailer: VLCMediaThumbnailer) {
        semaphore.signal()
    }
}
