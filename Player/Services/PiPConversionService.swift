import AVFoundation
import CryptoKit
import Foundation
import ffmpegkit

final class PiPConversionService {

    static let shared = PiPConversionService()

    static let libraryPipSubdir = "PiP"
    static let vlcFormatsForPipConversion: Set<String> = ["avi", "mkv", "webm", "flv", "wmv"]

    /// PiP — маленькое окно: ограничиваем разрешение и битрейт, чтобы уложиться в разумное время на устройстве.
    private static let pipVideoScaleFilter = "scale=-2:720"
    private static let pipVideoToolboxBitrate = "3.5M"
    /// Короче GOP — чаще I-кадры; перемотка AVPlayer по ключевым кадрам менее «тяжёлая», цена — чуть больше размер и время кодирования.
    private static let pipKeyframeInterval = 48

    private let fileManager = FileManager.default
    private let progressPercentLock = NSLock()
    private var progressPercentByItemId: [String: Int] = [:]
    private let activeConversionsLock = NSLock()
    private var activeItemIds = Set<String>()

    private init() {}

    func progressPercent(forItemId itemId: String) -> Int? {
        progressPercentLock.lock()
        defer { progressPercentLock.unlock() }
        return progressPercentByItemId[itemId]
    }

    /// Каталог PiP-MP4 в Documents (кэш переживает перезапуск; удаление — в `MediaStorageService.removeVideoItem`).
    func libraryPipDirectory(mediaDirectory: URL) -> URL {
        let dir = mediaDirectory.appendingPathComponent(Self.libraryPipSubdir, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func destinationMP4URL(forItemId itemId: String, mediaDirectory: URL) -> URL {
        let digest = SHA256.hash(data: Data(itemId.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined() + ".mp4"
        return libraryPipDirectory(mediaDirectory: mediaDirectory).appendingPathComponent(name)
    }

    func convertToMP4ForPip(sourceURL: URL, destinationURL: URL, itemId: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard sourceURL.isFileURL else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "PiPConversionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Only file URLs supported."])))
            }
            return
        }
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        let srcPath = sourceURL.path
        let dstPath = destinationURL.path
        let inputBytes = inputFileByteCount(at: srcPath)
        let sourceDurationSec = Self.sourceDurationSeconds(for: sourceURL)
        activeConversionsLock.lock()
        activeItemIds.insert(itemId)
        activeConversionsLock.unlock()
        progressPercentLock.lock()
        progressPercentByItemId[itemId] = 0
        progressPercentLock.unlock()

        // AVI: не remux с -c:v copy — часто битый MPEG-4 в контейнере; сразу H.264+AAC для AVPlayer/PiP.
        if sourceURL.pathExtension.lowercased() == "avi" {
            runTranscodeToMP4ForPip(sourcePath: srcPath, destinationPath: dstPath, destinationURL: destinationURL, itemId: itemId, inputBytes: inputBytes, sourceDurationSec: sourceDurationSec, completion: completion)
            return
        }

        // Remux: одна видеодорожка + первая аудио; иначе `-map 0:v` тянет все видеопотоки и MP4 ломает PiP.
        let remuxArgs = [
            "-fflags", "+genpts",
            "-i", srcPath,
            "-map", "0:v:0", "-map", "0:a:0?",
            "-c:v", "copy", "-c:a", "aac", "-b:a", "128k",
            "-movflags", "+faststart",
            "-y", dstPath
        ]
        FFmpegKit.execute(withArgumentsAsync: remuxArgs, withExecuteCallback: { [weak self] session in
            guard let self = self else { return }
            let rc = session?.getReturnCode()
            if let rc = rc, ReturnCode.isSuccess(rc) {
                self.validateOutputPlaysWithAVPlayer(at: destinationURL, itemId: itemId) { playable in
                    if playable {
                        self.finishConversion(itemId: itemId, result: .success(destinationURL), completion: completion)
                    } else {
                        if self.fileManager.fileExists(atPath: destinationURL.path) {
                            try? self.fileManager.removeItem(at: destinationURL)
                        }
                        self.runTranscodeToMP4ForPip(sourcePath: srcPath, destinationPath: dstPath, destinationURL: destinationURL, itemId: itemId, inputBytes: inputBytes, sourceDurationSec: sourceDurationSec, completion: completion)
                    }
                }
                return
            }
            if self.fileManager.fileExists(atPath: destinationURL.path) {
                try? self.fileManager.removeItem(at: destinationURL)
            }
            self.runTranscodeToMP4ForPip(sourcePath: srcPath, destinationPath: dstPath, destinationURL: destinationURL, itemId: itemId, inputBytes: inputBytes, sourceDurationSec: sourceDurationSec, completion: completion)
        }, withLogCallback: nil, withStatisticsCallback: { [weak self] stats in
            self?.postStatistics(itemId: itemId, stats: stats, inputBytes: inputBytes, sourceDurationSeconds: sourceDurationSec)
        })
    }

    /// Общий префикс транскода: генерировать PTS, одна видеодорожка и первая аудио.
    private static func pipTranscodeInputPrefix(sourcePath: String) -> [String] {
        ["-fflags", "+genpts", "-i", sourcePath, "-map", "0:v:0", "-map", "0:a:0?"]
    }

    /// `playable`, затем `AVPlayerItem` до `.readyToPlay` без seek-цикла (быстрая проверка после FFmpeg; seek при реальном PiP).
    private func validateOutputPlaysWithAVPlayer(at url: URL, itemId _: String, completion: @escaping (Bool) -> Void) {
        let asset = AVURLAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            var err: NSError?
            let status = asset.statusOfValue(forKey: "playable", error: &err)
            guard status == .loaded && asset.isPlayable else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            DispatchQueue.main.async {
                self.validatePlayerItemReadyForPiP(asset: asset, completion: completion)
            }
        }
    }

    private func validatePlayerItemReadyForPiP(asset: AVAsset, completion: @escaping (Bool) -> Void) {
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.volume = 0

        var finished = false
        var statusObservation: NSKeyValueObservation?

        func cleanup(_ ok: Bool) {
            guard !finished else { return }
            finished = true
            statusObservation?.invalidate()
            statusObservation = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
            completion(ok)
        }

        let timeoutSeconds: TimeInterval = 10
        let timeout = DispatchWorkItem { cleanup(false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: timeout)

        statusObservation = item.observe(\.status, options: [.new, .initial]) { playerItem, _ in
            DispatchQueue.main.async {
                guard !finished else { return }
                switch playerItem.status {
                case .readyToPlay:
                    timeout.cancel()
                    #if DEBUG
                    if asset.tracks(withMediaType: .video).count > 1 {
                        assertionFailure("PiP MP4 must have at most one video track (local transcode output)")
                    }
                    #endif
                    cleanup(true)
                case .failed:
                    timeout.cancel()
                    cleanup(false)
                default:
                    break
                }
            }
        }
        player.play()
    }

    private func runTranscodeToMP4ForPip(sourcePath: String, destinationPath: String, destinationURL: URL, itemId: String, inputBytes: Int64, sourceDurationSec: Double, completion: @escaping (Result<URL, Error>) -> Void) {
        if fileManager.fileExists(atPath: destinationPath) {
            try? fileManager.removeItem(at: destinationURL)
        }
        let gop = Self.pipKeyframeInterval
        let vtArgs = Self.pipTranscodeInputPrefix(sourcePath: sourcePath) + [
            "-vf", Self.pipVideoScaleFilter,
            "-c:v", "h264_videotoolbox", "-b:v", Self.pipVideoToolboxBitrate, "-allow_sw", "1",
            "-g", "\(gop)",
            "-c:a", "aac", "-b:a", "128k",
            "-movflags", "+faststart",
            "-y", destinationPath
        ]
        FFmpegKit.execute(withArgumentsAsync: vtArgs, withExecuteCallback: { [weak self] session in
            guard let self = self else { return }
            let rc = session?.getReturnCode()
            if let rc = rc, ReturnCode.isSuccess(rc) {
                self.validateOutputPlaysWithAVPlayer(at: destinationURL, itemId: itemId) { playable in
                    if playable {
                        self.finishConversion(itemId: itemId, result: .success(destinationURL), completion: completion)
                    } else {
                        if self.fileManager.fileExists(atPath: destinationPath) {
                            try? self.fileManager.removeItem(at: destinationURL)
                        }
                        self.runTranscodeLibx264BaselineForPip(sourcePath: sourcePath, destinationPath: destinationPath, destinationURL: destinationURL, itemId: itemId, inputBytes: inputBytes, sourceDurationSec: sourceDurationSec, completion: completion)
                    }
                }
                return
            }
            if self.fileManager.fileExists(atPath: destinationPath) {
                try? self.fileManager.removeItem(at: destinationURL)
            }
            self.runTranscodeLibx264BaselineForPip(sourcePath: sourcePath, destinationPath: destinationPath, destinationURL: destinationURL, itemId: itemId, inputBytes: inputBytes, sourceDurationSec: sourceDurationSec, completion: completion)
        }, withLogCallback: nil, withStatisticsCallback: { [weak self] stats in
            self?.postStatistics(itemId: itemId, stats: stats, inputBytes: inputBytes, sourceDurationSeconds: sourceDurationSec)
        })
    }

    private func runTranscodeLibx264BaselineForPip(sourcePath: String, destinationPath: String, destinationURL: URL, itemId: String, inputBytes: Int64, sourceDurationSec: Double, completion: @escaping (Result<URL, Error>) -> Void) {
        if fileManager.fileExists(atPath: destinationPath) {
            try? fileManager.removeItem(at: destinationURL)
        }
        let gop = Self.pipKeyframeInterval
        let transcodeArgs = Self.pipTranscodeInputPrefix(sourcePath: sourcePath) + [
            "-vf", Self.pipVideoScaleFilter,
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "24",
            "-profile:v", "baseline", "-level", "3.1", "-pix_fmt", "yuv420p",
            "-g", "\(gop)", "-keyint_min", "\(max(12, gop / 4))",
            "-c:a", "aac", "-b:a", "128k",
            "-movflags", "+faststart",
            "-y", destinationPath
        ]
        FFmpegKit.execute(withArgumentsAsync: transcodeArgs, withExecuteCallback: { [weak self] session in
            guard let self = self else { return }
            let rc = session?.getReturnCode()
            if let rc = rc, ReturnCode.isSuccess(rc) {
                self.validateOutputPlaysWithAVPlayer(at: destinationURL, itemId: itemId) { playable in
                    if playable {
                        self.finishConversion(itemId: itemId, result: .success(destinationURL), completion: completion)
                    } else {
                        let err = NSError(domain: "PiPConversionService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Conversion produced a file AVPlayer cannot play."])
                        self.finishConversion(itemId: itemId, result: .failure(err), completion: completion)
                    }
                }
            } else {
                let err = NSError(domain: "PiPConversionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Conversion failed."])
                self.finishConversion(itemId: itemId, result: .failure(err), completion: completion)
            }
        }, withLogCallback: nil, withStatisticsCallback: { [weak self] stats in
            self?.postStatistics(itemId: itemId, stats: stats, inputBytes: inputBytes, sourceDurationSeconds: sourceDurationSec)
        })
    }

    /// Длительность исходника для прогресса по времени (Statistics.getTime — миллисекунды).
    private static func sourceDurationSeconds(for url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        if let track = asset.tracks(withMediaType: .video).first {
            let s = CMTimeGetSeconds(track.timeRange.duration)
            if s.isFinite && s > 0 { return s }
        }
        let s = CMTimeGetSeconds(asset.duration)
        if s.isFinite && s > 0 { return s }
        return 0
    }

    private func inputFileByteCount(at path: String) -> Int64 {
        guard let n = try? fileManager.attributesOfItem(atPath: path)[.size] as? NSNumber else { return 0 }
        return n.int64Value
    }

    private func postStatistics(itemId: String, stats: Statistics?, inputBytes: Int64, sourceDurationSeconds: Double) {
        guard let stats = stats else { return }
        let percent: Int
        if sourceDurationSeconds > 0 {
            let processedSec = Double(stats.getTime()) / 1000.0
            percent = min(99, max(0, Int(processedSec * 100.0 / sourceDurationSeconds)))
        } else if inputBytes > 0 {
            let written = stats.getSize()
            percent = min(99, max(0, Int(Int64(written) * 100 / inputBytes)))
        } else {
            percent = 0
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.progressPercentLock.lock()
            self.progressPercentByItemId[itemId] = percent
            self.progressPercentLock.unlock()
            NotificationCenter.default.post(
                name: MediaStorageService.pipConversionProgressNotification,
                object: nil,
                userInfo: ["itemId": itemId, "progress": percent]
            )
        }
    }

    private func finishConversion(itemId: String, result: Result<URL, Error>, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.progressPercentLock.lock()
            self.progressPercentByItemId.removeValue(forKey: itemId)
            self.progressPercentLock.unlock()
            self.activeConversionsLock.lock()
            self.activeItemIds.remove(itemId)
            self.activeConversionsLock.unlock()
            completion(result)
            let ok: Bool
            if case .success = result { ok = true } else { ok = false }
            NotificationCenter.default.post(
                name: MediaStorageService.pipConversionFinishedNotification,
                object: nil,
                userInfo: ["itemId": itemId, "success": ok]
            )
        }
    }

    func isLibraryPipURL(_ url: URL, mediaDirectory: URL) -> Bool {
        let pipDir = libraryPipDirectory(mediaDirectory: mediaDirectory)
        return url.path.hasPrefix(pipDir.path)
    }

    func schedulePipConversionIfNeeded(for item: MediaItem, mediaDirectory: URL, completion: ((Bool) -> Void)? = nil) {
        guard item.kind == .video else {
            completion?(true)
            return
        }
        let ext = item.url.pathExtension.lowercased()
        guard Self.vlcFormatsForPipConversion.contains(ext) else {
            completion?(true)
            return
        }
        guard item.url.isFileURL, item.url.path.hasPrefix(mediaDirectory.path) else {
            completion?(true)
            return
        }
        if MediaStorageService.shared.loadPipConversionURL(itemId: item.id) != nil {
            if item.pipPreparation != .ready {
                MediaStorageService.shared.updateVideoItemPipPreparation(id: item.id, state: .ready)
            }
            completion?(true)
            return
        }
        let destURL = destinationMP4URL(forItemId: item.id, mediaDirectory: mediaDirectory)
        convertToMP4ForPip(sourceURL: item.url, destinationURL: destURL, itemId: item.id) { result in
            switch result {
            case .success(let url):
                MediaStorageService.shared.savePipConversionURL(itemId: item.id, url: url)
                MediaStorageService.shared.updateVideoItemPipPreparation(id: item.id, state: .ready)
                completion?(true)
            case .failure:
                MediaStorageService.shared.updateVideoItemPipPreparation(id: item.id, state: .failed)
                completion?(false)
            }
        }
    }

    func removeTempFileIfNeeded(_ url: URL) {
        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let libraryPip = docs.appendingPathComponent("Media", isDirectory: true).appendingPathComponent(Self.libraryPipSubdir, isDirectory: true)
            if url.path.hasPrefix(libraryPip.path) { return }
        }
        let legacyDir = fileManager.temporaryDirectory.appendingPathComponent("PiP", isDirectory: true)
        if url.path.hasPrefix(legacyDir.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Не вызывать `FFmpegKit.cancel()` глобально — прервётся фоновая конвертация для библиотеки при закрытии плеера.
    func cancel() {}
}
