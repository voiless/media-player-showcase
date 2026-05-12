import Foundation

protocol PlayerViewProtocol: AnyObject {
    func showProgress(current: TimeInterval, duration: TimeInterval)
    func showPlaybackState(isPlaying: Bool)
    func showItem(title: String, author: String?, coverImageURL: URL?)
    func showSpeed(_ speed: PlaybackSpeed)
    func showPlaybackMode(_ mode: PlaybackMode)
    func showError(_ message: String)
    func showUILocked(_ locked: Bool)
}
