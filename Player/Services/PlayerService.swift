import AVFoundation
import MobileVLCKit
import UIKit

protocol PlayerServiceDelegate: AnyObject {
    func playerService(_ service: PlayerService, didUpdateProgress current: TimeInterval, duration: TimeInterval)
    func playerServiceDidFinishPlaying(_ service: PlayerService)
    func playerService(_ service: PlayerService, didChangePlaybackState isPlaying: Bool)
    func playerService(_ service: PlayerService, didChangeCurrentItem item: MediaItem?)
    func playerService(_ service: PlayerService, didFailWithError error: Error)
}

final class PlayerService: NSObject {
    static let shared = PlayerService()
    /// Ошибки воспроизведения MP4, подготовленного для PiP (не подменять на общий текст «Файлы»).
    static let piPTranscodePlaybackErrorDomain = "PlayerService.PiPTranscodePlayback"
    static let playbackItemOrStateDidChangeNotification = Notification.Name("PlayerService.playbackItemOrStateDidChange")
    weak var delegate: PlayerServiceDelegate?
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var vlcPlayer: VLCMediaPlayer?
    private var vlcProgressTimer: Timer?
    private var vlcTrackedPosition: TimeInterval = 0
    private var vlcLastSaveTime: TimeInterval = 0
    private var vlcMaxReportedDuration: TimeInterval = 0
    private var vlcPlayPending = false
    private weak var videoDrawable: UIView?
    private var currentItem: MediaItem?
    private var queue: [MediaItem] = []
    private var currentIndex: Int = 0
    private var securityScopedFileURL: URL?
    private var isHandlingFinish = false
    private var transcodedPiPURL: URL?
    /// Ожидание `.readyToPlay` перед seek/play при переключении на PiP-MP4 (иначе часто AVFoundation -11800 unknown).
    private var pendingPiPCompletion: (() -> Void)?
    private var pendingPiPSeekTime: TimeInterval = 0
    private var pendingPiPActivationTimeout: DispatchWorkItem?
    var playbackMode: PlaybackMode = .stopAfterCurrent
    var audioPlaybackMode: PlaybackMode = .stopAfterCurrent
    var videoPlaybackMode: PlaybackMode = .stopAfterCurrent
    var speed: PlaybackSpeed = .normal
    var volume: Float = 1.0 {
        didSet {
            let v = max(0, min(1, volume))
            player?.volume = v
            vlcPlayer?.audio?.volume = Int32(v * 100)
        }
    }

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        if type == .began, isPlaying {
            DispatchQueue.main.async { [weak self] in
                self?.pause()
            }
        }
    }

    private func notifyPlaybackItemOrStateDidChange() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: Self.playbackItemOrStateDidChangeNotification, object: nil)
        } else {
            DispatchQueue.main.async { NotificationCenter.default.post(name: Self.playbackItemOrStateDidChangeNotification, object: nil) }
        }
    }

    private func releaseSecurityScopedResource() {
        securityScopedFileURL?.stopAccessingSecurityScopedResource()
        securityScopedFileURL = nil
    }

    var isVideoMode: Bool {
        currentItem?.kind == .video
    }

    var isVideoPlayedWithVLC: Bool {
        currentItem?.kind == .video && vlcPlayer != nil
    }

    var isPlaying: Bool {
        if isVideoPlayedWithVLC, let vlc = vlcPlayer {
            return vlc.isPlaying
        }
        return player?.rate != 0
    }

    var currentTime: TimeInterval {
        if isVideoPlayedWithVLC, let vlc = vlcPlayer {
            let t = vlc.time.intValue
            return TimeInterval(t) / 1000.0
        }
        let s = player?.currentTime().seconds ?? 0
        return s.isFinite ? s : 0
    }

    var duration: TimeInterval {
        if isVideoPlayedWithVLC, let vlc = vlcPlayer, let media = vlc.media {
            let len = media.length.intValue
            return TimeInterval(len) / 1000.0
        }
        guard let s = player?.currentItem?.duration.seconds, s.isFinite else { return 0 }
        return s
    }

    var currentMediaItem: MediaItem? {
        return currentItem
    }

    var queueItems: [MediaItem] {
        return queue
    }

    var currentPlayer: AVPlayer? {
        return player
    }

    func setVideoDrawable(_ view: UIView?) {
        videoDrawable = view
        guard isVideoPlayedWithVLC else { return }
        let apply: () -> Void = { [weak self] in
            guard let self = self, self.isVideoPlayedWithVLC else { return }
            self.vlcPlayer?.drawable = view
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    func pauseVLCAndDetachDrawableForPipConversion() {
        guard isVideoPlayedWithVLC else { return }
        let detach: () -> Void = { [weak self] in
            guard let self = self, self.isVideoPlayedWithVLC else { return }
            self.vlcPlayer?.pause()
            self.videoDrawable = nil
            self.vlcPlayer?.drawable = nil
        }
        if Thread.isMainThread {
            detach()
        } else {
            DispatchQueue.main.sync(execute: detach)
        }
    }

    func stopVLCForPipConversion() {
        stopVLC()
    }

    func startPendingVLCPlayIfNeeded() {
        guard vlcPlayPending, let vlc = vlcPlayer else { return }
        vlcPlayPending = false
        let positionToRestore = vlcTrackedPosition
        vlc.drawable = videoDrawable
        vlc.play()
        startVLCProgressTimer()
        vlcLastSaveTime = 0
        vlcMaxReportedDuration = 0
        if positionToRestore > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self = self, self.isVideoPlayedWithVLC, self.vlcPlayer === vlc else { return }
                vlc.time = VLCTime(int: Self.vlcMilliseconds(positionToRestore))
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, self.isVideoPlayedWithVLC else { return }
                self.saveProgress()
            }
        }
        delegate?.playerService(self, didChangePlaybackState: true)
        notifyPlaybackItemOrStateDidChange()
        isHandlingFinish = false
        let isAVI = currentItem?.url.pathExtension.lowercased() == "avi"
        if isAVI, positionToRestore == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self = self, self.vlcPlayer === vlc else { return }
                vlc.time = VLCTime(int: 5000)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self = self, self.vlcPlayer === vlc else { return }
                vlc.time = VLCTime(int: 0)
            }
        }
    }

    func stopVideoPlaybackAndDetachView() {
        let work = { [weak self] in
            guard let self = self else { return }
            self.tearDownVLCMediaPlayerOnly()
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// Stops VLC without releasing security-scoped URL access (AVPlayer may still be playing the same file).
    private func tearDownVLCMediaPlayerOnly() {
        vlcPlayPending = false
        vlcProgressTimer?.invalidate()
        vlcProgressTimer = nil
        let vlc = vlcPlayer
        vlcPlayer = nil
        vlc?.stop()
        vlc?.delegate = nil
        vlc?.drawable = nil
        if vlc != nil {
            DispatchQueue.main.async { _ = vlc }
        }
    }



    func vlcSubtitleTrackCount() -> Int {
        guard let vlc = vlcPlayer else { return 0 }
        let names = vlc.videoSubTitlesNames as? [String] ?? []
        return names.count
    }

    func vlcSubtitleTrackNames() -> [String] {
        guard let vlc = vlcPlayer else { return [] }
        return (vlc.videoSubTitlesNames as? [String]) ?? []
    }

    func vlcCurrentSubtitleIndex() -> Int {
        guard let vlc = vlcPlayer else { return 0 }
        let idx = vlc.currentVideoSubTitleIndex
        let indexes = (vlc.videoSubTitlesIndexes as? [NSNumber]) ?? []
        for (i, num) in indexes.enumerated() where num.intValue == idx {
            return i
        }
        return 0
    }

    func vlcSetSubtitleIndex(_ index: Int) {
        guard let vlc = vlcPlayer else { return }
        let indexes = (vlc.videoSubTitlesIndexes as? [NSNumber]) ?? []
        if index < 0 || index >= indexes.count {
            vlc.currentVideoSubTitleIndex = -1
            return
        }
        vlc.currentVideoSubTitleIndex = Int32(indexes[index].intValue)
    }

    func vlcAudioTrackCount() -> Int {
        guard let vlc = vlcPlayer else { return 0 }
        return Int(vlc.numberOfAudioTracks)
    }

    func vlcAudioTrackNames() -> [String] {
        guard let vlc = vlcPlayer else { return [] }
        return (vlc.audioTrackNames as? [String]) ?? []
    }

    func vlcCurrentAudioTrackIndex() -> Int {
        guard let vlc = vlcPlayer else { return 0 }
        let idx = vlc.currentAudioTrackIndex
        let indexes = (vlc.audioTrackIndexes as? [NSNumber]) ?? []
        for (i, num) in indexes.enumerated() where num.intValue == idx {
            return i
        }
        return 0
    }

    func vlcSetAudioTrackIndex(_ index: Int) {
        guard let vlc = vlcPlayer else { return }
        let indexes = (vlc.audioTrackIndexes as? [NSNumber]) ?? []
        if index < 0 || index >= indexes.count {
            vlc.currentAudioTrackIndex = -1
            return
        }
        vlc.currentAudioTrackIndex = Int32(indexes[index].intValue)
    }

    func setQueue(_ items: [MediaItem], startIndex: Int = 0) {
        let newIndex = min(max(0, startIndex), items.count - 1)
        if !items.isEmpty, newIndex < items.count,
           queue.map(\.id) == items.map(\.id),
           currentItem?.id == items[newIndex].id {
            queue = items
            currentIndex = newIndex
            currentItem = items[newIndex]
            delegate?.playerService(self, didChangeCurrentItem: currentItem)
            NotificationCenter.default.post(name: Self.playbackItemOrStateDidChangeNotification, object: nil)
            return
        }
        queue = items
        currentIndex = newIndex
        if !queue.isEmpty && currentIndex < queue.count {
            playItem(queue[currentIndex], restorePosition: true)
        }
    }

    private static let avPlayerVideoExtensions: Set<String> = ["mp4", "mov", "m4v", "mpeg4", "m4p", "3gp"]
    private static let avPlayerFirstTryExtensions: Set<String> = ["avi", "mkv"]

    private func isAVPlayerCompatibleVideo(_ url: URL) -> Bool {
        let ext = (url.pathExtension as NSString).lowercased
        return Self.avPlayerVideoExtensions.contains(ext)
    }

    private func isAVPlayerFirstTryVideo(_ url: URL) -> Bool {
        let ext = (url.pathExtension as NSString).lowercased
        return Self.avPlayerFirstTryExtensions.contains(ext)
    }

    func playItem(_ item: MediaItem, restorePosition: Bool = true) {
        PiPConversionService.shared.cancel()
        if let oldURL = transcodedPiPURL {
            PiPConversionService.shared.removeTempFileIfNeeded(oldURL)
            transcodedPiPURL = nil
        }
        releaseSecurityScopedResource()
        currentItem = item
        vlcTrackedPosition = 0
        if item.kind == .video {
            MediaStorageService.shared.addToRecentVideoHistory(itemId: item.id)
            stopVLC()
            stopAVPlayback()
            if isAVPlayerCompatibleVideo(item.url) {
                playVideoWithAVPlayer(item: item, restorePosition: restorePosition, fallbackToVLCOnFailure: false)
            } else if isAVPlayerFirstTryVideo(item.url) {
                playVideoWithAVPlayer(item: item, restorePosition: restorePosition, fallbackToVLCOnFailure: true)
            } else {
                playVideoWithVLC(item: item, restorePosition: restorePosition)
            }
        } else if item.kind == .audio {
            MediaStorageService.shared.addToRecentAudioHistory(itemId: item.id)
            stopVLC()
            playerItem?.removeObserver(self, forKeyPath: "status")
            if item.url.isFileURL, item.url.startAccessingSecurityScopedResource() {
                securityScopedFileURL = item.url
            }
            let asset = AVURLAsset(url: item.url)
            let keys = ["playable"]
            asset.loadValuesAsynchronously(forKeys: keys) { [weak self] in
                guard let self = self else { return }
                var loadError: NSError?
                let status = asset.statusOfValue(forKey: "playable", error: &loadError)
                DispatchQueue.main.async {
                    guard self.currentItem?.id == item.id else { return }
                    if status == .failed, let err = loadError {
                        self.delegate?.playerService(self, didFailWithError: err)
                        return
                    }
                    if status != .loaded || !asset.isPlayable {
                        let err = loadError ?? NSError(domain: AVFoundation.AVError.errorDomain, code: AVFoundation.AVError.fileFormatNotRecognized.rawValue, userInfo: [NSLocalizedDescriptionKey: "The file could not be opened."])
                        self.delegate?.playerService(self, didFailWithError: err)
                        return
                    }
                    self.attachAndPlayAudio(asset: asset, item: item, restorePosition: restorePosition)
                }
            }
        }
    }

    private func playVideoWithAVPlayer(item: MediaItem, restorePosition: Bool = true, fallbackToVLCOnFailure: Bool = false) {
        if item.url.isFileURL, item.url.startAccessingSecurityScopedResource() {
            securityScopedFileURL = item.url
        }
        let asset = AVURLAsset(url: item.url)
        let keys = ["playable"]
        asset.loadValuesAsynchronously(forKeys: keys) { [weak self] in
            guard let self = self else { return }
            var loadError: NSError?
            let status = asset.statusOfValue(forKey: "playable", error: &loadError)
            DispatchQueue.main.async {
                guard self.currentItem?.id == item.id else { return }
                if status == .failed, let err = loadError {
                    if fallbackToVLCOnFailure {
                        self.playVideoWithVLC(item: item, restorePosition: restorePosition)
                    } else {
                        self.delegate?.playerService(self, didFailWithError: err)
                    }
                    return
                }
                if status != .loaded || !asset.isPlayable {
                    if fallbackToVLCOnFailure {
                        self.playVideoWithVLC(item: item, restorePosition: restorePosition)
                    } else {
                        let err = loadError ?? NSError(domain: AVFoundation.AVError.errorDomain, code: AVFoundation.AVError.fileFormatNotRecognized.rawValue, userInfo: [NSLocalizedDescriptionKey: "The file could not be opened."])
                        self.delegate?.playerService(self, didFailWithError: err)
                    }
                    return
                }
                self.attachAndPlayVideo(asset: asset, item: item, restorePosition: restorePosition)
            }
        }
    }

    /// Загрузка AVAsset сразу после остановки VLCKit иногда даёт -11800: даём GL/декодеру время завершить сброс буферов на главном потоке.
    private static let pipPostVLCDelay: TimeInterval = 0.1

    func switchToTranscodedMP4ForPiP(tempMP4URL: URL, seekTime: TimeInterval, completion: @escaping () -> Void) {
        let run: () -> Void = { [weak self] in
            self?.switchToTranscodedMP4ForPiPOnMain(tempMP4URL: tempMP4URL, seekTime: seekTime, completion: completion)
        }
        if Thread.isMainThread {
            run()
        } else {
            DispatchQueue.main.async(execute: run)
        }
    }

    private func switchToTranscodedMP4ForPiPOnMain(tempMP4URL: URL, seekTime: TimeInterval, completion: @escaping () -> Void) {
        assert(Thread.isMainThread)
        guard let item = currentItem, isVideoPlayedWithVLC else {
            completion()
            return
        }
        let position = seekTime
        stopVLC()
        stopAVPlayback()
        transcodedPiPURL = tempMP4URL
        let asset = AVURLAsset(url: tempMP4URL)
        let itemId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pipPostVLCDelay) { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion() }
                return
            }
            self.loadTranscodedPiPAsset(asset: asset, itemId: itemId, position: position, tempMP4URL: tempMP4URL, completion: completion)
        }
    }

    private func loadTranscodedPiPAsset(asset: AVURLAsset, itemId: String, position: TimeInterval, tempMP4URL: URL, completion: @escaping () -> Void) {
        asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
            guard let self = self else { DispatchQueue.main.async { completion() }; return }
            var err: NSError?
            let status = asset.statusOfValue(forKey: "playable", error: &err)
            DispatchQueue.main.async {
                guard self.currentItem?.id == itemId else { DispatchQueue.main.async { completion() }; return }
                if status != .loaded || !asset.isPlayable {
                    self.transcodedPiPURL = nil
                    PiPConversionService.shared.removeTempFileIfNeeded(tempMP4URL)
                    var failInfo: [String: Any] = [NSLocalizedDescriptionKey: AppStrings.pipTranscodeMp4PlaybackFailed]
                    if let loadErr = err { failInfo[NSUnderlyingErrorKey] = loadErr }
                    let fail = NSError(domain: Self.piPTranscodePlaybackErrorDomain, code: 1, userInfo: failInfo)
                    self.delegate?.playerService(self, didFailWithError: fail)
                    completion()
                    return
                }
                let itemToPlay = AVPlayerItem(asset: asset)
                itemToPlay.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
                self.playerItem = itemToPlay
                if self.player == nil {
                    self.player = AVPlayer(playerItem: itemToPlay)
                } else {
                    self.player?.replaceCurrentItem(with: itemToPlay)
                }
                self.pendingPiPSeekTime = position
                self.pendingPiPCompletion = completion
                self.pendingPiPActivationTimeout?.cancel()
                let timeout = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    guard self.pendingPiPCompletion != nil else { return }
                    self.pendingPiPCompletion = nil
                    let err = NSError(
                        domain: Self.piPTranscodePlaybackErrorDomain,
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: AppStrings.pipTranscodeMp4PlaybackFailed]
                    )
                    self.delegate?.playerService(self, didFailWithError: err)
                    completion()
                }
                self.pendingPiPActivationTimeout = timeout
                DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: timeout)
                self.performPiPPlaybackStartIfPending()
            }
        }
    }

    private func attachAndPlayVideo(asset: AVAsset, item: MediaItem, restorePosition: Bool = true) {
        let itemToPlay = AVPlayerItem(asset: asset)
        itemToPlay.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        playerItem = itemToPlay
        if player == nil {
            player = AVPlayer(playerItem: itemToPlay)
        } else {
            player?.replaceCurrentItem(with: itemToPlay)
        }
        setupTimeObserver()
        player?.volume = volume
        player?.currentItem?.preferredPeakBitRate = 0
        if restorePosition, let last = MediaStorageService.shared.loadLastPlayback(), last.itemId == item.id, last.time > 0 {
            player?.seek(to: CMTime(seconds: last.time, preferredTimescale: 600))
        }
        player?.play()
        player?.rate = speed.rawValue
        NotificationCenter.default.addObserver(self, selector: #selector(itemDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: itemToPlay)
        delegate?.playerService(self, didChangePlaybackState: true)
        delegate?.playerService(self, didChangeCurrentItem: currentItem)
        notifyPlaybackItemOrStateDidChange()
        isHandlingFinish = false
    }

    private func playVideoWithVLC(item: MediaItem, restorePosition: Bool = true) {
        if item.url.isFileURL, item.url.startAccessingSecurityScopedResource() {
            securityScopedFileURL = item.url
        }
        let media: VLCMedia
        if item.url.isFileURL {
            media = VLCMedia(path: item.url.path)
        } else {
            media = VLCMedia(url: item.url)
        }
        let vlc = VLCMediaPlayer()
        vlc.delegate = self
        vlc.media = media
        if Thread.isMainThread {
            vlc.drawable = videoDrawable
        } else {
            DispatchQueue.main.sync { vlc.drawable = self.videoDrawable }
        }
        vlc.audio?.volume = Int32(volume * 100)
        vlc.rate = speed.rawValue
        vlcPlayer = vlc
        if restorePosition, let last = MediaStorageService.shared.loadLastPlayback(), last.time > 0 {
            let idMatch = last.itemId == item.id
            let pathMatch = item.url.isFileURL && (MediaStorageService.shared.mediaItem(byId: last.itemId)?.url.path == item.url.path)
            if idMatch || pathMatch {
                vlc.time = VLCTime(int: Self.vlcMilliseconds(last.time))
                vlcTrackedPosition = last.time
            } else {
                vlcTrackedPosition = 0
            }
        } else {
            vlcTrackedPosition = 0
        }
        vlcPlayPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.playerService(self, didChangeCurrentItem: self.currentItem)
            self.notifyPlaybackItemOrStateDidChange()
            self.startPendingVLCPlayIfNeeded()
        }
    }

    private func stopVLC() {
        let body: () -> Void = { [weak self] in
            self?.performStopVLCOnMainThread()
        }
        if Thread.isMainThread {
            body()
        } else {
            DispatchQueue.main.sync(execute: body)
        }
    }

    /// VLCKit трогает drawable/OpenGL view с воркеров; pause/drawable/stop только с main.
    private func performStopVLCOnMainThread() {
        assert(Thread.isMainThread)
        vlcPlayPending = false
        releaseSecurityScopedResource()
        vlcProgressTimer?.invalidate()
        vlcProgressTimer = nil
        let vlc = vlcPlayer
        vlcPlayer = nil
        vlc?.pause()
        vlc?.drawable = nil
        vlc?.stop()
        vlc?.delegate = nil
        if vlc != nil {
            DispatchQueue.main.async { _ = vlc }
        }
    }

    private func startVLCProgressTimer() {
        vlcProgressTimer?.invalidate()
        vlcLastSaveTime = 0
        vlcMaxReportedDuration = 0
        vlcProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isVideoMode else { return }
            let cur = self.currentTime
            let dur = self.duration
            if dur > self.vlcMaxReportedDuration {
                self.vlcMaxReportedDuration = dur
            }
            self.vlcTrackedPosition = cur
            let endDur = max(dur, self.vlcMaxReportedDuration)
            if endDur > 0, cur >= endDur - 0.01, cur <= endDur + 2, self.isPlaying {
                self.handleDidFinish()
                return
            }
            self.delegate?.playerService(self, didUpdateProgress: cur, duration: dur)
            if self.delegate == nil, let item = self.currentItem {
                NowPlayingService.shared.update(
                    item: item,
                    currentTime: cur,
                    duration: dur,
                    isPlaying: self.isPlaying,
                    throttleProgress: true
                )
            }
            let now = CACurrentMediaTime()
            let interval = Self.vlcPeriodicSaveInterval(secondsPlayed: cur)
            if cur > 0, now - self.vlcLastSaveTime >= interval {
                self.vlcLastSaveTime = now
                self.saveProgress()
            }
        }
        vlcProgressTimer?.tolerance = 0.1
        RunLoop.main.add(vlcProgressTimer!, forMode: .common)
    }

    private static func vlcPeriodicSaveInterval(secondsPlayed cur: TimeInterval) -> TimeInterval {
        if cur < 60 { return 2 }
        if cur < 600 { return 5 }
        if cur < 3600 { return 10 }
        if cur < 36_000 { return 30 }
        return 60
    }

    private static func vlcMilliseconds(_ seconds: TimeInterval) -> Int32 {
        let ms = seconds * 1000
        return Int32(min(max(0, ms), Double(Int32.max)))
    }

    private func stopAVPlayback() {
        pendingPiPActivationTimeout?.cancel()
        pendingPiPActivationTimeout = nil
        pendingPiPCompletion = nil
        releaseSecurityScopedResource()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        playerItem?.removeObserver(self, forKeyPath: "status")
        player?.replaceCurrentItem(with: nil)
        player?.pause()
        playerItem = nil
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
        }
        timeObserver = nil
    }

    private func performPiPPlaybackStartIfPending() {
        guard transcodedPiPURL != nil, let completion = pendingPiPCompletion else { return }
        guard let item = playerItem, item.status == .readyToPlay else { return }
        pendingPiPCompletion = nil
        pendingPiPActivationTimeout?.cancel()
        pendingPiPActivationTimeout = nil
        let position = pendingPiPSeekTime
        setupTimeObserver()
        player?.automaticallyWaitsToMinimizeStalling = false
        player?.volume = volume
        player?.currentItem?.preferredPeakBitRate = 0
        player?.seek(to: CMTime(seconds: position, preferredTimescale: 600)) { [weak self] finished in
            guard let self = self else { return }
            if !finished {
                let err = NSError(
                    domain: Self.piPTranscodePlaybackErrorDomain,
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: AppStrings.pipTranscodeMp4PlaybackFailed]
                )
                self.delegate?.playerService(self, didFailWithError: err)
                completion()
                return
            }
            self.player?.play()
            self.player?.rate = self.speed.rawValue
            if let it = self.playerItem {
                NotificationCenter.default.addObserver(self, selector: #selector(self.itemDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: it)
            }
            self.delegate?.playerService(self, didChangePlaybackState: true)
            self.delegate?.playerService(self, didChangeCurrentItem: self.currentItem)
            self.notifyPlaybackItemOrStateDidChange()
            self.isHandlingFinish = false
            completion()
        }
    }

    private func attachAndPlayAudio(asset: AVAsset, item: MediaItem, restorePosition: Bool = true) {
        let itemToPlay = AVPlayerItem(asset: asset)
        itemToPlay.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        playerItem = itemToPlay
        if player == nil {
            player = AVPlayer(playerItem: itemToPlay)
        } else {
            player?.replaceCurrentItem(with: itemToPlay)
        }
        setupTimeObserver()
        player?.volume = volume
        player?.currentItem?.preferredPeakBitRate = 0
        if restorePosition, let last = MediaStorageService.shared.loadLastPlayback(), last.itemId == item.id, last.time > 0 {
            player?.seek(to: CMTime(seconds: last.time, preferredTimescale: 600))
        }
        player?.play()
        player?.rate = speed.rawValue
        NotificationCenter.default.addObserver(self, selector: #selector(itemDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: itemToPlay)
        delegate?.playerService(self, didChangePlaybackState: true)
        notifyPlaybackItemOrStateDidChange()
        isHandlingFinish = false
    }

    func play() {
        let dur = duration
        let atEnd = dur > 0 && currentTime >= dur - 0.5
        if currentItem != nil, !queue.isEmpty, !isPlaying, atEnd {
            if isVideoPlayedWithVLC, vlcPlayer != nil, let item = currentItem {
                vlcProgressTimer?.invalidate()
                vlcProgressTimer = nil
                stopVLC()
                playVideoWithVLC(item: item, restorePosition: false)
                startPendingVLCPlayIfNeeded()
                return
            }
            if !isVideoPlayedWithVLC, let p = player {
                if playerItem != nil {
                    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
                    NotificationCenter.default.addObserver(self, selector: #selector(itemDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
                }
                p.seek(to: .zero) { [weak self] finished in
                    guard let self = self, finished else { return }
                    self.player?.play()
                    self.player?.rate = self.speed.rawValue
                    self.delegate?.playerService(self, didChangePlaybackState: true)
                }
                return
            }
        }
        if isVideoPlayedWithVLC, let vlc = vlcPlayer {
            let vlcAtEnd = (vlc.state == .ended || vlc.state == .stopped) || (dur > 0 && currentTime >= dur - 1)
            if vlcAtEnd, let item = currentItem {
                vlcProgressTimer?.invalidate()
                vlcProgressTimer = nil
                stopVLC()
                playVideoWithVLC(item: item, restorePosition: false)
                startPendingVLCPlayIfNeeded()
                return
            }
            vlc.play()
            vlc.rate = speed.rawValue
            startVLCProgressTimer()
            delegate?.playerService(self, didChangePlaybackState: true)
        } else if !isVideoPlayedWithVLC {
            if let item = player?.currentItem {
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
                NotificationCenter.default.addObserver(self, selector: #selector(itemDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: item)
            }
            player?.play()
            player?.rate = speed.rawValue
            delegate?.playerService(self, didChangePlaybackState: true)
            notifyPlaybackItemOrStateDidChange()
        }
    }

    func pause() {
        saveProgress()
        if isVideoPlayedWithVLC {
            vlcPlayer?.pause()
        } else {
            player?.pause()
        }
        if Thread.isMainThread {
            delegate?.playerService(self, didChangePlaybackState: false)
            notifyPlaybackItemOrStateDidChange()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.playerService(self, didChangePlaybackState: false)
                self.notifyPlaybackItemOrStateDidChange()
            }
        }
    }

    func clearPlayback() {
        pendingPiPActivationTimeout?.cancel()
        pendingPiPActivationTimeout = nil
        pendingPiPCompletion = nil
        releaseSecurityScopedResource()
        stopVLC()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        playerItem?.removeObserver(self, forKeyPath: "status")
        player?.replaceCurrentItem(with: nil)
        player?.pause()
        playerItem = nil
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
        }
        timeObserver = nil
        currentItem = nil
        queue = []
        currentIndex = 0
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.playerService(self, didChangeCurrentItem: nil)
            self.delegate?.playerService(self, didChangePlaybackState: false)
            self.notifyPlaybackItemOrStateDidChange()
        }
    }

    func refreshCurrentItemMetadataFromStorage() {
        guard let current = currentItem, current.kind == .audio,
              let fresh = MediaStorageService.shared.mediaItem(byId: current.id) else { return }
        let updated = MediaItem(id: current.id, url: current.url, kind: current.kind, title: fresh.title, author: fresh.author, coverImageURL: fresh.coverImageURL, duration: current.duration, status: current.status, pipPreparation: current.pipPreparation)
        currentItem = updated
        if currentIndex < queue.count, queue[currentIndex].id == current.id {
            queue[currentIndex] = updated
        }
        delegate?.playerService(self, didChangeCurrentItem: currentItem)
        notifyPlaybackItemOrStateDidChange()
    }

    func handleAudioItemRemoved(id: String) {
        guard currentItem?.kind == .audio else { return }
        if currentItem?.id == id {
            clearPlayback()
            return
        }
        queue.removeAll { $0.id == id }
        if queue.isEmpty {
            clearPlayback()
            return
        }
        if let idx = queue.firstIndex(where: { $0.id == currentItem?.id }) {
            currentIndex = idx
        } else {
            currentIndex = min(currentIndex, queue.count - 1)
        }
        notifyPlaybackItemOrStateDidChange()
    }

    func saveProgress() {
        guard let item = currentItem else { return }
        let dur = duration
        let useTrackedForVideo = item.kind == .video && (isVideoPlayedWithVLC || vlcTrackedPosition > 0)
        let timeToSave: TimeInterval = useTrackedForVideo ? vlcTrackedPosition : currentTime
        let endReference = max(dur, vlcMaxReportedDuration)
        let plausiblyAtEnd = endReference > 0
            && timeToSave >= endReference - 0.5
            && timeToSave <= endReference + 2
        if plausiblyAtEnd {
            MediaStorageService.shared.clearLastPlayback(itemId: item.id)
        } else {
            MediaStorageService.shared.saveLastPlayback(itemId: item.id, time: timeToSave)
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// - Parameter looseTolerance: для перемотки после жеста/ползунка — ближайший ключевой кадр в окне ~0.5 с, меньше нагрузка на декодер, чем точный seek подряд.
    func seek(to time: TimeInterval, looseTolerance: Bool = false) {
        let dur = duration
        let clamped = max(0, dur > 0 ? min(time, dur) : max(0, time))
        if isVideoPlayedWithVLC {
            vlcPlayer?.time = VLCTime(int: Self.vlcMilliseconds(clamped))
        } else {
            let cm = CMTime(seconds: clamped, preferredTimescale: 600)
            if looseTolerance {
                let tol = CMTime(seconds: 0.5, preferredTimescale: 600)
                player?.seek(to: cm, toleranceBefore: tol, toleranceAfter: tol)
            } else {
                player?.seek(to: cm)
            }
        }
    }

    func seek(offset: TimeInterval) {
        let newTime = max(0, min(currentTime + offset, duration))
        seek(to: newTime)
    }

    func setRate(_ speed: PlaybackSpeed) {
        self.speed = speed
        if isPlaying {
            if isVideoPlayedWithVLC {
                vlcPlayer?.rate = speed.rawValue
            } else {
                player?.rate = speed.rawValue
            }
        }
    }

    func next() {
        if queue.isEmpty { return }
        if queue.count == 1 {
            seek(to: 0)
            play()
            return
        }
        switch playbackMode {
        case .repeatOne:
            advanceToNext()
        case .repeatAll, .shuffle, .stopAfterCurrent:
            advanceToNext()
        }
    }

    func previous() {
        if queue.isEmpty { return }
        if currentTime > 3 {
            seek(to: 0)
            play()
        } else if currentIndex > 0 {
            currentIndex -= 1
            playItem(queue[currentIndex], restorePosition: false)
        } else {
            currentIndex = queue.count - 1
            playItem(queue[currentIndex], restorePosition: false)
        }
    }

    private func advanceToNext() {
        if queue.isEmpty { return }
        if playbackMode == .shuffle {
            currentIndex = Int.random(in: 0..<queue.count)
        } else {
            currentIndex = (currentIndex + 1) % queue.count
        }
        playItem(queue[currentIndex], restorePosition: false)
    }

    @objc private func itemDidFinish() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        handleDidFinish()
    }

    private func handleDidFinish() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.handleDidFinish()
            }
            return
        }
        if isHandlingFinish { return }
        isHandlingFinish = true
        delegate?.playerService(self, didChangePlaybackState: false)
        notifyPlaybackItemOrStateDidChange()
        switch playbackMode {
        case .repeatOne:
            if isVideoPlayedWithVLC {
                seek(to: 0)
                play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.isHandlingFinish = false
                }
            } else {
                player?.seek(to: .zero) { [weak self] _ in
                    guard let self = self else { return }
                    if let item = self.player?.currentItem {
                        NotificationCenter.default.addObserver(self, selector: #selector(self.itemDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: item)
                    }
                    self.player?.play()
                    self.player?.rate = self.speed.rawValue
                    self.delegate?.playerService(self, didChangePlaybackState: true)
                    self.notifyPlaybackItemOrStateDidChange()
                    self.isHandlingFinish = false
                }
            }
        case .repeatAll:
            if queue.isEmpty {
                pause()
                delegate?.playerService(self, didChangePlaybackState: false)
                delegate?.playerServiceDidFinishPlaying(self)
                notifyPlaybackItemOrStateDidChange()
            } else if currentIndex >= queue.count - 1 {
                currentIndex = 0
                playItem(queue[currentIndex], restorePosition: false)
            } else {
                currentIndex += 1
                playItem(queue[currentIndex], restorePosition: false)
            }
        case .shuffle:
            if queue.count <= 1 {
                pause()
                delegate?.playerService(self, didChangePlaybackState: false)
                delegate?.playerServiceDidFinishPlaying(self)
                notifyPlaybackItemOrStateDidChange()
            } else {
                advanceToNext()
            }
        case .stopAfterCurrent:
            pause()
            delegate?.playerService(self, didChangePlaybackState: false)
            delegate?.playerServiceDidFinishPlaying(self)
            notifyPlaybackItemOrStateDidChange()
        }
        let didAdvanceToNextTrack: Bool
        switch playbackMode {
        case .repeatAll: didAdvanceToNextTrack = !queue.isEmpty
        case .repeatOne: didAdvanceToNextTrack = true
        case .shuffle: didAdvanceToNextTrack = queue.count > 1
        case .stopAfterCurrent: didAdvanceToNextTrack = false
        }
        if !didAdvanceToNextTrack {
            DispatchQueue.main.async { [weak self] in
                self?.isHandlingFinish = false
            }
        }
    }

    private func setupTimeObserver() {
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
        }
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] _ in
            guard let self = self else { return }
            let cur = self.currentTime
            let dur = self.duration
            if dur > 0, cur >= dur - 0.01, self.isPlaying {
                self.handleDidFinish()
                return
            }
            self.delegate?.playerService(self, didUpdateProgress: cur, duration: dur)
            if self.delegate == nil, let item = self.currentItem {
                NowPlayingService.shared.update(
                    item: item,
                    currentTime: cur,
                    duration: dur,
                    isPlaying: self.isPlaying,
                    throttleProgress: true
                )
            }
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let item = object as? AVPlayerItem {
            if item.status == .readyToPlay, item === playerItem, transcodedPiPURL != nil {
                DispatchQueue.main.async { [weak self] in
                    self?.performPiPPlaybackStartIfPending()
                }
            }
            if item.status == .failed, let error = item.error {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.pendingPiPCompletion != nil {
                        self.pendingPiPActivationTimeout?.cancel()
                        self.pendingPiPActivationTimeout = nil
                        self.pendingPiPCompletion = nil
                    }
                    if self.transcodedPiPURL != nil {
                        let wrapped = NSError(
                            domain: Self.piPTranscodePlaybackErrorDomain,
                            code: 2,
                            userInfo: [
                                NSLocalizedDescriptionKey: AppStrings.pipTranscodeMp4PlaybackFailed,
                                NSUnderlyingErrorKey: error
                            ]
                        )
                        self.delegate?.playerService(self, didFailWithError: wrapped)
                    } else {
                        self.delegate?.playerService(self, didFailWithError: error)
                    }
                }
            }
        }
    }

    deinit {
        stopVLC()
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
        }
        playerItem?.removeObserver(self, forKeyPath: "status")
        NotificationCenter.default.removeObserver(self)
    }
}

extension PlayerService: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let vlc = vlcPlayer else { return }
        switch vlc.state {
        case .playing, .buffering:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.playerService(self, didChangePlaybackState: true)
            }
        case .paused:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.playerService(self, didChangePlaybackState: false)
            }
        case .ended, .stopped:
            vlcProgressTimer?.invalidate()
            vlcProgressTimer = nil
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.playerService(self, didChangePlaybackState: false)
                if vlc.state == .ended {
                    self.handleDidFinish()
                }
            }
        case .error:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.playerService(self, didFailWithError: NSError(domain: "VLC", code: -1, userInfo: [NSLocalizedDescriptionKey: AppStrings.fileCouldNotBeOpened]))
            }
        default:
            break
        }
    }
}
