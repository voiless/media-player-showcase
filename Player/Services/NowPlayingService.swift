import MediaPlayer
import UIKit

final class NowPlayingService: NSObject {
    static let shared = NowPlayingService()

    private var lastProgressUpdate: TimeInterval = 0
    private let progressUpdateInterval: TimeInterval = 1.0

    private override init() {
        super.init()
    }

    func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget(self, action: #selector(handlePlayCommand))

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget(self, action: #selector(handlePauseCommand))

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget(self, action: #selector(handleTogglePlayPauseCommand))

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget(self, action: #selector(handleNextCommand))

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget(self, action: #selector(handlePreviousCommand))

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget(self, action: #selector(handleChangePlaybackPositionCommand(_:)))
    }

    @objc private func handlePlayCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        handlePlay()
        return .success
    }

    @objc private func handlePauseCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        handlePause()
        return .success
    }

    @objc private func handleTogglePlayPauseCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        handleTogglePlayPause()
        return .success
    }

    @objc private func handleNextCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        handleNext()
        return .success
    }

    @objc private func handlePreviousCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        handlePrevious()
        return .success
    }

    @objc private func handleChangePlaybackPositionCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
        handleSeek(to: e.positionTime)
        return .success
    }

    private func handlePlay() {
        DispatchQueue.main.async {
            PlayerService.shared.play()
        }
    }

    private func handlePause() {
        DispatchQueue.main.async {
            PlayerService.shared.pause()
        }
    }

    private func handleTogglePlayPause() {
        DispatchQueue.main.async {
            PlayerService.shared.togglePlayPause()
        }
    }

    private func handleNext() {
        DispatchQueue.main.async {
            PlayerService.shared.next()
        }
    }

    private func handlePrevious() {
        DispatchQueue.main.async {
            PlayerService.shared.previous()
        }
    }

    private func handleSeek(to time: TimeInterval) {
        DispatchQueue.main.async {
            PlayerService.shared.seek(to: time)
        }
    }

    func update(
        item: MediaItem?,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        throttleProgress: Bool = true
    ) {
        guard let item = item else {
            clear()
            return
        }

        if throttleProgress {
            let now = CACurrentMediaTime()
            if now - lastProgressUpdate < progressUpdateInterval, abs((MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] as? Double ?? 0) - duration) < 0.1 {
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyPlaybackDuration] = duration
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
                info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
                return
            }
            lastProgressUpdate = now
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.displayTitle,
            MPMediaItemPropertyArtist: item.author ?? "",
            MPMediaItemPropertyPlaybackDuration: max(0, duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let artwork = artwork(for: item) {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused

        loadArtworkAsync(for: item) { [weak self] artwork in
            guard self != nil,
                  let artwork = artwork,
                  PlayerService.shared.currentMediaItem?.id == item.id else { return }
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    private func artwork(for item: MediaItem) -> MPMediaItemArtwork? {
        if let url = item.coverImageURL, url.isFileURL {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
        }
        if let image = DefaultCover.image(for: item.kind) {
            return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        return nil
    }

    private func loadArtworkAsync(for item: MediaItem, completion: @escaping (MPMediaItemArtwork?) -> Void) {
        guard item.coverImageURL != nil else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let art = self?.artwork(for: item)
            DispatchQueue.main.async { completion(art) }
        }
    }
}
