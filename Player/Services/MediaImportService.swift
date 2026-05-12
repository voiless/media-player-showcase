import UIKit
import UniformTypeIdentifiers

protocol MediaImportServiceDelegate: AnyObject {
    func mediaImportServiceDidFinishImporting(_ service: MediaImportService)
    func mediaImportService(_ service: MediaImportService, didFailWithError error: Error)
}

final class MediaImportService: NSObject {
    static let shared = MediaImportService()
    weak var delegate: MediaImportServiceDelegate?
    private var lastPickerKind: MediaItemKind = .video
    private weak var presentingViewController: UIViewController?

    // MARK: - Public API

    func presentAddSource(from viewController: UIViewController, kind: MediaItemKind) {
        lastPickerKind = kind
        presentingViewController = viewController
        let addSource = AddVideoSourceViewController(mode: kind == .video ? .video : .audio)
        addSource.delegate = self
        addSource.modalPresentationStyle = .overFullScreen
        addSource.modalTransitionStyle = .crossDissolve
        viewController.present(addSource, animated: true)
    }

    // MARK: - Helper Methods

    private func showAddMediaError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: AppStrings.cannotOpen, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: AppStrings.ok, style: .default))
            self?.presentingViewController?.present(alert, animated: true)
        }
    }

    private func copyToAppAndAdd(url: URL, kind: MediaItemKind) {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let mediaDir = docs.appendingPathComponent("Media", isDirectory: true)
        try? fm.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        let name = url.lastPathComponent
        let dest = mediaDir.appendingPathComponent(name)

        let process = { [weak self] in
            guard let self = self else { return }
            do {
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: url, to: dest)
                if kind == .video {
                    let ext = dest.pathExtension.lowercased()
                    let needsPipConversion = PiPConversionService.vlcFormatsForPipConversion.contains(ext)
                    let item = MediaItem(id: dest.absoluteString, url: dest, kind: .video, title: url.deletingPathExtension().lastPathComponent, author: nil, coverImageURL: nil, duration: 0, status: .ready, pipPreparation: needsPipConversion ? .pending : .notApplicable)
                    MediaStorageService.shared.addVideoItem(item)
                    self.scheduleVideoCoverGeneration(itemId: item.id, url: dest)
                    PiPConversionService.shared.schedulePipConversionIfNeeded(for: item, mediaDirectory: mediaDir, completion: nil)
                } else {
                    let (title, artist) = AudioMetadataService.loadTitleAndArtist(from: dest)
                    let item = MediaItem(id: dest.absoluteString, url: dest, kind: .audio, title: title, author: artist, coverImageURL: nil, duration: 0, status: .ready)
                    MediaStorageService.shared.addAudioItem(item)
                    self.scheduleAudioCoverGeneration(itemId: item.id, url: dest)
                }
                self.delegate?.mediaImportServiceDidFinishImporting(self)
            } catch {
                if kind == .video {
                    self.showAddMediaError(AppStrings.couldNotAddVideo)
                } else {
                    self.showAddMediaError(AppStrings.couldNotAddAudio)
                }
                self.delegate?.mediaImportService(self, didFailWithError: error)
            }
        }

        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            process()
        } else {
            process()
        }
    }

    private func importAudiosFromFolder(url: URL) {
        let fm = FileManager.default
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        let audioExt = ["mp3", "wav", "aac", "m4a", "flac", "ogg", "opus"]
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
                let ext = fileURL.pathExtension.lowercased()
                if audioExt.contains(ext) {
                    let (title, artist) = AudioMetadataService.loadTitleAndArtist(from: fileURL)
                    let item = MediaItem(id: fileURL.absoluteString, url: fileURL, kind: .audio, title: title, author: artist, coverImageURL: nil, duration: 0, status: .ready)
                    MediaStorageService.shared.addAudioItem(item)
                    scheduleAudioCoverGeneration(itemId: item.id, url: fileURL)
                }
            }
        }
        delegate?.mediaImportServiceDidFinishImporting(self)
    }

    private func importVideosFromFolder(url: URL) {
        let fm = FileManager.default
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        let videoExt = ["mp4", "mkv", "mov", "avi", "m4v", "webm", "3gp"]
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        let mediaDir = docs?.appendingPathComponent("Media", isDirectory: true)

        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
                let ext = fileURL.pathExtension.lowercased()
                if videoExt.contains(ext) {
                    // For folder import, we might not copy? The original code didn't seem to copy in playVideosFromFolder!
                    // Wait, MenuViewController.swift lines 346-363:
                    // It creates MediaItem with fileURL.absoluteString.
                    // If fileURL is inside the picked folder, we need access rights.
                    // But security scoped resource access is only valid while we hold the scope.
                    // If we don't copy, we lose access!
                    // The original code was potentially buggy for folder imports if it didn't copy.
                    // Or maybe it assumed the user picked a folder that persists access?
                    // Security scoped bookmarks are needed.
                    // MediaStorageService handles bookmarks if we pass the original URL.
                    
                    let needsPip = PiPConversionService.vlcFormatsForPipConversion.contains(ext)
                    let pipPrep: PipPreparationState = needsPip ? (mediaDir != nil ? .pending : .notApplicable) : .notApplicable
                    let item = MediaItem(id: fileURL.absoluteString, url: fileURL, kind: .video, title: fileURL.deletingPathExtension().lastPathComponent, author: nil, coverImageURL: nil, duration: 0, status: .ready, pipPreparation: pipPrep)
                    MediaStorageService.shared.addVideoItem(item)
                    scheduleVideoCoverGeneration(itemId: item.id, url: fileURL)
                    if let mediaDir = mediaDir {
                        PiPConversionService.shared.schedulePipConversionIfNeeded(for: item, mediaDirectory: mediaDir, completion: nil)
                    }
                }
            }
        }
        delegate?.mediaImportServiceDidFinishImporting(self)
    }

    private func scheduleVideoCoverGeneration(itemId: String, url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let coverURL = VideoThumbnailService.generateThumbnail(for: url, itemId: itemId) else { return }
            DispatchQueue.main.async {
                MediaStorageService.shared.updateVideoItemCover(id: itemId, coverURL: coverURL)
                NotificationCenter.default.post(name: MediaStorageService.mediaCoversDidUpdateNotification, object: nil)
            }
        }
    }

    private func scheduleAudioCoverGeneration(itemId: String, url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let coverURL = AudioMetadataService.extractAndSaveArtwork(from: url, itemId: itemId) else { return }
            DispatchQueue.main.async {
                MediaStorageService.shared.updateAudioItemCover(id: itemId, coverURL: coverURL)
                NotificationCenter.default.post(name: MediaStorageService.mediaCoversDidUpdateNotification, object: nil)
            }
        }
    }
}

// MARK: - AddVideoSourceDelegate
extension MediaImportService: AddVideoSourceDelegate {
    func addVideoSourceDidSelectFiles() {
        let types: [UTType]
        if lastPickerKind == .audio {
            types = [.audio, .mp3, .mpeg4Audio, UTType(filenameExtension: "flac", conformingTo: .audio), UTType(filenameExtension: "ogg", conformingTo: .audio), UTType(filenameExtension: "wav", conformingTo: .audio), UTType(filenameExtension: "m4a", conformingTo: .audio)].compactMap { $0 }
        } else {
            types = [
                .movie, .mpeg4Movie, .quickTimeMovie, .video,
                UTType("org.matroska.mkv"), UTType("public.avi"), UTType("public.webm"),
                UTType("public.flv"), UTType("public.wmv"),
                UTType(filenameExtension: "m4v", conformingTo: .video),
                UTType(filenameExtension: "3gp", conformingTo: .video)
            ].compactMap { $0 }
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presentingViewController?.present(picker, animated: true)
    }

    func addVideoSourceDidSelectFolder() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presentingViewController?.present(picker, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate
extension MediaImportService: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        let kind = lastPickerKind
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isDirectory {
                if kind == .audio {
                    self.importAudiosFromFolder(url: url)
                } else {
                    self.importVideosFromFolder(url: url)
                }
            } else {
                self.copyToAppAndAdd(url: url, kind: kind)
            }
        }
    }
}
