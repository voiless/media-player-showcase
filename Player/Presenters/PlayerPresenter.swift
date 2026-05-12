import AVFoundation
import Foundation
import os
import UIKit

final class PlayerPresenter: PlayerPresenterProtocol, PlayerServiceDelegate {
    private static let pipPlaybackLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Player", category: "PiP")

    weak var view: PlayerViewProtocol?
    private let playerService: PlayerService
    private var pendingQueue: [MediaItem]?
    private var pendingStartIndex: Int = 0
    private var lastPlaybackState: Bool = false

    init(view: PlayerViewProtocol, playerService: PlayerService) {
        self.view = view
        self.playerService = playerService
        self.playerService.delegate = self
    }

    func setQueue(_ items: [MediaItem], startIndex: Int) {
        pendingQueue = items
        pendingStartIndex = startIndex
    }

    func viewDidLoad() {
        if let queue = pendingQueue {
            playerService.setQueue(queue, startIndex: pendingStartIndex)
            pendingQueue = nil
        }
        lastPlaybackState = playerService.isPlaying
        updateViewFromService()
        syncNowPlaying()
    }

    func refreshPlaybackState() {
        view?.showPlaybackState(isPlaying: lastPlaybackState)
    }

    func syncPlaybackStateFromService() {
        lastPlaybackState = playerService.isPlaying
        view?.showPlaybackState(isPlaying: lastPlaybackState)
    }

    func refreshPlaybackMode() {
        view?.showPlaybackMode(playerService.playbackMode)
    }

    private func syncNowPlaying() {
        let service = playerService
        NowPlayingService.shared.update(
            item: service.currentMediaItem,
            currentTime: service.currentTime,
            duration: service.duration,
            isPlaying: lastPlaybackState,
            throttleProgress: true
        )
    }

    private func updateViewFromService() {
        if let item = playerService.currentMediaItem {
            view?.showItem(title: item.displayTitle, author: item.author, coverImageURL: item.coverImageURL)
        }
        view?.showProgress(current: playerService.currentTime, duration: playerService.duration)
        view?.showPlaybackState(isPlaying: lastPlaybackState)
        view?.showSpeed(playerService.speed)
        view?.showPlaybackMode(playerService.playbackMode)
    }

    func didTapPlayPause() {
        playerService.togglePlayPause()
    }

    func didTapNext() {
        playerService.next()
    }

    func didTapPrevious() {
        playerService.previous()
    }

    func didTapSpeed() {
        let all = PlaybackSpeed.allCases
        guard let idx = all.firstIndex(of: playerService.speed) else { return }
        let next = all[(idx + 1) % all.count]
        playerService.setRate(next)
        view?.showSpeed(next)
    }

    func didTapRepeat() {
        switch playerService.audioPlaybackMode {
        case .stopAfterCurrent:
            playerService.audioPlaybackMode = .repeatAll
        case .repeatAll:
            playerService.audioPlaybackMode = .repeatOne
        case .repeatOne:
            playerService.audioPlaybackMode = .stopAfterCurrent
        case .shuffle:
            playerService.audioPlaybackMode = .repeatAll
        }
        playerService.playbackMode = playerService.audioPlaybackMode
        view?.showPlaybackMode(playerService.playbackMode)
    }

    func didTapShuffle(isAudioMode: Bool) {
        if isAudioMode {
            playerService.audioPlaybackMode = playerService.audioPlaybackMode == .shuffle ? .stopAfterCurrent : .shuffle
            playerService.playbackMode = playerService.audioPlaybackMode
        } else {
            playerService.videoPlaybackMode = playerService.videoPlaybackMode == .shuffle ? .stopAfterCurrent : .shuffle
            playerService.playbackMode = playerService.videoPlaybackMode
        }
        view?.showPlaybackMode(playerService.playbackMode)
    }

    func didSetAutoplay(_ on: Bool) {
        if on {
            if playerService.videoPlaybackMode != .shuffle {
                playerService.videoPlaybackMode = .repeatAll
            }
        } else {
            playerService.videoPlaybackMode = .stopAfterCurrent
        }
        playerService.playbackMode = playerService.videoPlaybackMode
        view?.showPlaybackMode(playerService.playbackMode)
    }

    func didSeek(to progress: Double) {
        let duration = playerService.duration
        playerService.seek(to: progress * duration, looseTolerance: true)
    }

    func didChangeSpeed(_ speed: PlaybackSpeed) {
        playerService.setRate(speed)
        view?.showSpeed(speed)
    }

    func didChangeBrightness(_ value: Float) {
        UIScreen.main.brightness = CGFloat(value)
    }

    func didRequestLockUI() {
        view?.showUILocked(true)
    }

    func didRequestUnlockUI() {
        view?.showUILocked(false)
    }

    func playerService(_ service: PlayerService, didUpdateProgress current: TimeInterval, duration: TimeInterval) {
        view?.showProgress(current: current, duration: duration)
        syncNowPlaying()
    }

    func playerServiceDidFinishPlaying(_ service: PlayerService) {
        lastPlaybackState = false
        view?.showPlaybackState(isPlaying: false)
        syncNowPlaying()
    }

    func playerService(_ service: PlayerService, didChangePlaybackState isPlaying: Bool) {
        lastPlaybackState = isPlaying
        view?.showPlaybackState(isPlaying: isPlaying)
        if let item = service.currentMediaItem {
            view?.showItem(title: item.displayTitle, author: item.author, coverImageURL: item.coverImageURL)
        }
        syncNowPlaying()
    }

    func playerService(_ service: PlayerService, didChangeCurrentItem item: MediaItem?) {
        guard let item = item else {
            NowPlayingService.shared.clear()
            return
        }
        view?.showItem(title: item.displayTitle, author: item.author, coverImageURL: item.coverImageURL)
        syncNowPlaying()
    }

    func playerService(_ service: PlayerService, didFailWithError error: Error) {
        let message: String
        let ns = error as NSError
        if ns.domain == PlayerService.piPTranscodePlaybackErrorDomain {
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                Self.pipPlaybackLog.error("PiP playback: \(underlying.domain, privacy: .public) code=\(underlying.code, privacy: .public) \(underlying.localizedDescription, privacy: .public)")
            }
            #if DEBUG
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                message = "\(AppStrings.pipTranscodeMp4PlaybackFailed)\n[\(underlying.domain) \(underlying.code)] \(underlying.localizedDescription)"
            } else {
                message = AppStrings.pipTranscodeMp4PlaybackFailed
            }
            #else
            message = AppStrings.pipTranscodeMp4PlaybackFailed
            #endif
        } else {
            let desc = error.localizedDescription
            if desc.lowercased().contains("cannot open") || ns.domain == AVFoundation.AVError.errorDomain {
                message = AppStrings.fileCouldNotBeOpenedHint
            } else {
                message = desc
            }
        }
        view?.showError(message)
    }
}
