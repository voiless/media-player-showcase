import CryptoKit
import Foundation
import UIKit

enum MediaCoverCache {
    private static let folderName = "MediaCovers"
    private static let fileExtension = "jpg"

    static func coverDirectory() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = support.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cacheFilename(itemId: String, kind: String) -> String {
        let data = Data(itemId.utf8)
        let hash = SHA256.hash(data: data)
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        return "\(kind)_\(hex).\(fileExtension)"
    }

    static func coverURL(forFilename filename: String) -> URL? {
        guard let dir = coverDirectory() else { return nil }
        return dir.appendingPathComponent(filename)
    }

    static func saveImage(_ image: UIImage, itemId: String, kind: String, size: CGSize) -> URL? {
        guard let dir = coverDirectory() else { return nil }
        let scaled = image.resized(to: size)
        guard let data = scaled.jpegData(compressionQuality: 0.85) else { return nil }
        let name = cacheFilename(itemId: itemId, kind: kind)
        let fileURL = dir.appendingPathComponent(name)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    static func clearAll() {
        guard let dir = coverDirectory() else { return }
        try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
    }
}

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
