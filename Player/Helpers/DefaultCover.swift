import UIKit

enum DefaultCover {
    static func image(for kind: MediaItemKind) -> UIImage? {
        switch kind {
        case .video: return UIImage(named: "video-cover")
        case .audio: return UIImage(named: "audio-background")
        }
    }

    static var videoCover: UIImage? { UIImage(named: "video-cover") }
    static var albumCreateCover: UIImage? { UIImage(named: "album-create-cover") }
    static var albumCover: UIImage? { UIImage(named: "album-cover") }
    static var albumCreateCover155x135: UIImage? {
        guard let img = albumCreateCover else { return nil }
        return imageResized(to: CGSize(width: 155, height: 135), img)
    }
    static var playlistFolderCover155x135: UIImage? {
        let img = UIImage(named: "album-covered-image") ?? UIImage(named: "album-cover")
        guard let image = img else { return nil }
        return imageResized(to: CGSize(width: 155, height: 135), image)
    }
    private static func imageResized(to size: CGSize, _ img: UIImage) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    static var audioBackground: UIImage? { UIImage(named: "audio-background") }
}
