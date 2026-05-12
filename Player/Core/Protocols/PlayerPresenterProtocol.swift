import Foundation

protocol PlayerPresenterProtocol: AnyObject {
    func viewDidLoad()
    func refreshPlaybackState()
    func syncPlaybackStateFromService()
    func refreshPlaybackMode()
    func didTapPlayPause()
    func didTapNext()
    func didTapPrevious()
    func didTapSpeed()
    func didSeek(to progress: Double)
    func didChangeSpeed(_ speed: PlaybackSpeed)
    func didChangeBrightness(_ value: Float)
    func didRequestLockUI()
    func didRequestUnlockUI()
    func didSetAutoplay(_ on: Bool)
    func didTapShuffle(isAudioMode: Bool)
    func didTapRepeat()
}
