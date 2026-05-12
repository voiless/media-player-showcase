import UIKit
import UniformTypeIdentifiers

final class StartViewController: UIViewController {

    private let selectButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.setTitle(AppStrings.selectFile, for: .normal)
        b.titleLabel?.font = AppTypography.headline
        b.fitTitleWithinBounds(maxLines: 2)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = AppStrings.player
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: AppStrings.library, style: .plain, target: self, action: #selector(openLibrary))
        view.addSubview(selectButton)
        NSLayoutConstraint.activate([
            selectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            selectButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        selectButton.addTarget(self, action: #selector(selectFileTapped), for: .touchUpInside)
    }

    @objc private func selectFileTapped() {
        let types: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie, .video, .audio, .mp3, .mpeg4Audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    @objc private func openLibrary() {
        let library = LibraryViewController()
        library.presenter = LibraryPresenter(view: library)
        let nav = UINavigationController(rootViewController: library)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func playItem(_ item: MediaItem) {
        let playerVC = PlayerViewController()
        let presenter = PlayerPresenter(view: playerVC, playerService: PlayerService.shared)
        playerVC.presenter = presenter
        playerVC.setQueue([item], startIndex: 0)
        let nav = PlayerNavigationController(rootViewController: playerVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
}

extension StartViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let mediaDir = docs.appendingPathComponent("Media", isDirectory: true)
        try? fm.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        let name = url.lastPathComponent
        let dest = mediaDir.appendingPathComponent(name)
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: url, to: dest)
                playItem(makeMediaItem(url: dest))
            } catch {
                playItem(makeMediaItem(url: url))
            }
        } else {
            playItem(makeMediaItem(url: url))
        }
    }

    private func makeMediaItem(url: URL) -> MediaItem {
        let ext = (url.path as NSString).pathExtension.lowercased()
        let kind: MediaItemKind = ["mp4", "mkv", "mov", "avi", "flv", "wmv", "webm", "m4v", "3gp"].contains(ext) ? .video : .audio
        return MediaItem(id: url.absoluteString, url: url, kind: kind, title: url.deletingPathExtension().lastPathComponent, author: nil, coverImageURL: nil, duration: 0)
    }
}
