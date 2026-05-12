import AVFoundation
import AVKit
import UIKit

final class PlayerViewController: UIViewController, PlayerViewProtocol, UIGestureRecognizerDelegate, AVPictureInPictureControllerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let tap = gestureRecognizer as? UITapGestureRecognizer, tap.view === view {
            var v: UIView? = touch.view
            while let node = v {
                if node is UIControl { return false }
                v = node.superview
            }
            return true
        }
        if let pan = gestureRecognizer as? UIPanGestureRecognizer, pan.view === view {
            guard !volumeSliderPanel.isHidden, let host = volumeSliderPanel.superview else { return true }
            let pt = touch.location(in: host)
            if volumeSliderPanel.frame.contains(pt) { return false }
            return true
        }
        return true
    }

    var presenter: PlayerPresenter?
    private var queue: [MediaItem] = []
    private var startIndex: Int = 0

    private var playerLayer: AVPlayerLayer?
    private let vlcVideoView: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private var pipController: Any?

    private let backgroundImageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let titleLabel = UILabel()
    private let titleMarqueeContainer = UIView()
    private var titleMarqueeWidth: CGFloat = 0
    private var marqueeAnimation: UIViewPropertyAnimator?
    private let progressSlider = UISlider()
    private let currentTimeLabel = UILabel()
    private let remainingTimeLabel = UILabel()
    private let playNextButton = TouchTargetButton(type: .custom)
    private let playPauseButton = TouchTargetButton(type: .system)
    private let nextButton = TouchTargetButton(type: .system)
    private let previousButton = TouchTargetButton(type: .system)
    private let speedButton = TouchTargetButton(type: .system)
    private let shuffleButton = TouchTargetButton(type: .system)
    private let backButton = TouchTargetButton(type: .system)
    private let castButton = TouchTargetButton(type: .system)
    private let volumeButton = TouchTargetButton(type: .system)
    private let pipButton = TouchTargetButton(type: .system)
    private let subtitlesButton = TouchTargetButton(type: .system)
    private let audioTrackButton = TouchTargetButton(type: .system)
    private let lockButton = TouchTargetButton(type: .system)
    private let rotateButton = TouchTargetButton(type: .system)
    private var subtitlesOn = false
    private var playNextOn = false
    private let unlockOverlay = UIView()
    private var pipWaitingForItemId: String?
    private var pipConversionObservers: [NSObjectProtocol] = []
    private let volumeSliderPanel = UIView()
    private let volumeSlider = UISlider()
    private let brightnessOverlayLabel = UILabel()
    private var brightnessOverlayHideWorkItem: DispatchWorkItem?
    private var topBarContainer: UIView!
    private var topBarTopToSafeArea: NSLayoutConstraint?
    private var topBarTopToView: NSLayoutConstraint?
    private var topBarHeightConstraint: NSLayoutConstraint?
    private var backButtonLeadingConstraint: NSLayoutConstraint?
    private var castButtonTrailingConstraint: NSLayoutConstraint?
    private var centerControlsContainer: UIView!
    private var bottomControlsContainer: UIView!
    private var controlsContainer: UIView!
    private var isUILocked = false
    private var brightnessGestureStart: CGFloat = 0
    private var holdSpeedTimer: Timer?
    private var panStartProgress: Double = 0
    private var speedBeforeHold: PlaybackSpeed = .normal
    private var controlsHideTimer: Timer?
    private var controlsVisible = true
    private var suppressScreenTapUntil: CFTimeInterval = 0
    private let overlayLockButton = TouchTargetButton(type: .system)
    private var overlayLockHideTimer: Timer?
    private var isOverlayLockButtonVisible = false

    private enum PanDirection { case brightness, seek }
    private var activePanDirection: PanDirection?

    /// Пока тянем ползунок — не зовём `seek` на каждый тик; только локальные подписи времени.
    private var isVideoScrubbing = false
    private var isAudioScrubbing = false
    /// Горизонтальный pan «перемотка»: обновляем UI, один `seek` в конце жеста.
    private var isPanSeekInProgress = false
    private var panSeekLastProgress: Double = 0

    private var playerLockedOrientationMask: UIInterfaceOrientationMask = .portrait

    private var audioContainerView: UIView!
    private let albumArtImageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.backgroundColor = UIColor(white: 0.15, alpha: 1)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let audioTitleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFonts.bold(20)
        l.textColor = .white
        l.textAlignment = .left
        l.numberOfLines = 1
        l.fitTextWithinBounds(multiline: false)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let audioSubtitleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFonts.regular(16)
        l.textColor = UIColor.white.withAlphaComponent(0.8)
        l.textAlignment = .left
        l.numberOfLines = 1
        l.fitTextWithinBounds(multiline: false)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let audioProgressSlider = UISlider()
    private let audioCurrentTimeLabel = UILabel()
    private let audioRemainingTimeLabel = UILabel()
    private let audioShuffleButton = TouchTargetButton(type: .system)
    private let audioPrevButton = TouchTargetButton(type: .system)
    private let audioPlayPauseButton = TouchTargetButton(type: .system)
    private let audioNextButton = TouchTargetButton(type: .system)
    private let audioRepeatButton = TouchTargetButton(type: .system)

    private var isAudioMode: Bool {
        PlayerService.shared.currentMediaItem?.kind == .audio
    }

    func setQueue(_ items: [MediaItem], startIndex: Int) {
        queue = items
        self.startIndex = startIndex
        presenter?.setQueue(items, startIndex: startIndex)
        if startIndex >= 0 && startIndex < items.count {
            let kind = items[startIndex].kind
            if kind == .audio {
                backgroundImageView.image = UIImage(named: "load_back")
                backgroundImageView.contentMode = .scaleAspectFill
                backgroundImageView.backgroundColor = .clear
            } else {
                backgroundImageView.image = nil
                backgroundImageView.backgroundColor = .black
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupVideoLayer()
        setupControls()
        setupGestures()
        if !queue.isEmpty, startIndex >= 0, startIndex < queue.count, queue[startIndex].kind == .video {
            PlayerService.shared.setVideoDrawable(vlcVideoView)
        }
        PlayerService.shared.playbackMode = isAudioMode ? PlayerService.shared.audioPlaybackMode : PlayerService.shared.videoPlaybackMode
        presenter?.viewDidLoad()
        let useVLCAtLoad = !isAudioMode && PlayerService.shared.isVideoPlayedWithVLC
        playerLayer?.player = useVLCAtLoad ? nil : PlayerService.shared.currentPlayer
        playerLayer?.frame = view.bounds
        PlayerService.shared.setVideoDrawable(isAudioMode ? nil : (PlayerService.shared.isVideoPlayedWithVLC ? vlcVideoView : nil))
        scheduleControlsHide()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if traitCollection.userInterfaceIdiom == .phone, let windowScene = view.window?.windowScene {
            let current = windowScene.interfaceOrientation
            let isPortrait = current == .portrait || current == .portraitUpsideDown
            playerLockedOrientationMask = isPortrait ? .portrait : .landscape
            if #available(iOS 16.0, *) {
                setNeedsUpdateOfSupportedInterfaceOrientations()
                let geometry = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: playerLockedOrientationMask)
                windowScene.requestGeometryUpdate(geometry) { _ in }
            }
        }
        let useVLCNow = !isAudioMode && PlayerService.shared.isVideoPlayedWithVLC
        playerLayer?.player = useVLCNow ? nil : PlayerService.shared.currentPlayer
        playerLayer?.frame = view.bounds
        PlayerService.shared.setVideoDrawable(isAudioMode ? nil : (PlayerService.shared.isVideoPlayedWithVLC ? vlcVideoView : nil))
        PlayerService.shared.startPendingVLCPlayIfNeeded()
        updateVolumeButtonIcon()
        setupPiPIfNeeded()
        updateLayoutForMode()
        if isAudioMode {
            PlayerService.shared.refreshCurrentItemMetadataFromStorage()
        }
        if !isUILocked {
            controlsContainer.isUserInteractionEnabled = true
        }
        PlayerService.shared.playbackMode = isAudioMode ? PlayerService.shared.audioPlaybackMode : PlayerService.shared.videoPlaybackMode
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.syncPlaybackStateFromService()
            self?.presenter?.refreshPlaybackMode()
        }
        let oFinish = NotificationCenter.default.addObserver(forName: MediaStorageService.pipConversionFinishedNotification, object: nil, queue: .main) { [weak self] note in
            self?.handlePipConversionFinishedNotification(note)
        }
        pipConversionObservers = [oFinish]
    }

    deinit {
        pipConversionObservers.forEach { NotificationCenter.default.removeObserver($0) }
        brightnessOverlayHideWorkItem?.cancel()
    }

    private func setupPiPIfNeeded() {
        guard pipController == nil, let layer = playerLayer, layer.player != nil else { return }
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        guard !isAudioMode else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
        if #available(iOS 15.0, *) {
            pipController = AVPictureInPictureController(contentSource: .init(playerLayer: layer))
        } else {
            pipController = AVPictureInPictureController(playerLayer: layer)
        }
        (pipController as? AVPictureInPictureController)?.delegate = self
        if #available(iOS 14.2, *) {
            (pipController as? AVPictureInPictureController)?.canStartPictureInPictureAutomaticallyFromInline = true
        }
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        AppOrientationState.setPictureInPictureActive(true)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        AppOrientationState.setPictureInPictureActive(false)
        if traitCollection.userInterfaceIdiom == .phone {
            playerLockedOrientationMask = .portrait
            if #available(iOS 16.0, *) {
                setNeedsUpdateOfSupportedInterfaceOrientations()
            } else {
                UIViewController.attemptRotationToDeviceOrientation()
            }
            AppOrientationState.requestPortraitPhone(view.window?.windowScene)
        }
        presenter?.syncPlaybackStateFromService()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
        startMarqueeIfNeeded()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if isAudioMode {
            topBarHeightConstraint?.constant = 44 + view.safeAreaInsets.top
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        controlsHideTimer?.invalidate()
        controlsHideTimer = nil
        if !isUILocked {
            controlsVisible = true
            controlsContainer?.isUserInteractionEnabled = true
            controlsContainer?.alpha = 1
        }
        volumeSliderPanel.isHidden = true
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self = self else { return }
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            self.playerLayer?.frame = self.view.bounds
            if !self.isUILocked, !self.isAudioMode {
                self.scheduleControlsHide()
            }
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if traitCollection.userInterfaceIdiom == .pad {
            return .all
        }
        if AppOrientationState.isPictureInPictureActive {
            return [.portrait, .landscapeLeft, .landscapeRight]
        }
        return playerLockedOrientationMask
    }

    override var shouldAutorotate: Bool {
        AppOrientationState.isPictureInPictureActive || traitCollection.userInterfaceIdiom == .pad
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        rotateButton.isHidden = (traitCollection.userInterfaceIdiom == .pad)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        PiPConversionService.shared.cancel()
        pipWaitingForItemId = nil
        controlsHideTimer?.invalidate()
        controlsHideTimer = nil
        overlayLockHideTimer?.invalidate()
        overlayLockHideTimer = nil
        brightnessOverlayHideWorkItem?.cancel()
        brightnessOverlayHideWorkItem = nil
        PlayerService.shared.saveProgress()
        PlayerService.shared.stopVideoPlaybackAndDetachView()
    }

    private func setupVideoLayer() {
        view.addSubview(backgroundImageView)
        view.addSubview(vlcVideoView)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            vlcVideoView.topAnchor.constraint(equalTo: view.topAnchor),
            vlcVideoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vlcVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vlcVideoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        backgroundImageView.backgroundColor = .black
        backgroundImageView.image = nil
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, above: backgroundImageView.layer)
        playerLayer = layer
    }

    private func setupControls() {
        navigationController?.setNavigationBarHidden(true, animated: false)

        controlsContainer = UIView()
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.backgroundColor = .clear
        view.addSubview(controlsContainer)
        topBarContainer = UIView()
        topBarContainer.translatesAutoresizingMaskIntoConstraints = false
        topBarContainer.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        controlsContainer.addSubview(topBarContainer)
        backButton.setImage(imageResizedTo24(UIImage(named: "back")), for: .normal)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        backButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleMarqueeContainer.clipsToBounds = true
        titleMarqueeContainer.translatesAutoresizingMaskIntoConstraints = false
        titleMarqueeContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleMarqueeContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.font = AppTypography.title
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.text = AppStrings.nameFile
        titleLabel.numberOfLines = 1
        titleLabel.fitTextWithinBounds(multiline: false)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleMarqueeContainer.addSubview(titleLabel)
        castButton.setImage(imageResizedTo24(UIImage(named: "caste")), for: .normal)
        castButton.tintColor = .white
        castButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        castButton.addTarget(self, action: #selector(castTapped), for: .touchUpInside)
        updateVolumeButtonIcon()
        volumeButton.tintColor = .white
        volumeButton.addTarget(self, action: #selector(volumeButtonTapped), for: .touchUpInside)
        volumeButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        [backButton, titleMarqueeContainer, castButton, volumeButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        topBarContainer.addSubview(backButton)
        topBarContainer.addSubview(titleMarqueeContainer)
        topBarContainer.addSubview(castButton)
        topBarContainer.addSubview(volumeButton)

        centerControlsContainer = UIView()
        centerControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        centerControlsContainer.backgroundColor = .clear
        controlsContainer.addSubview(centerControlsContainer)
        previousButton.setImage(imageResizedTo(CGSize(width: 43, height: 43), UIImage(named: "prev")), for: .normal)
        previousButton.tintColor = .white
        previousButton.addTarget(self, action: #selector(tapPrevious), for: .touchUpInside)
        playPauseButton.setImage(imageResizedTo(CGSize(width: 69, height: 69), UIImage(named: "play")), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.addTarget(self, action: #selector(tapPlayPause), for: .touchUpInside)
        nextButton.setImage(imageResizedTo(CGSize(width: 43, height: 43), UIImage(named: "next")), for: .normal)
        nextButton.tintColor = .white
        nextButton.addTarget(self, action: #selector(tapNext), for: .touchUpInside)
        [previousButton, playPauseButton, nextButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        centerControlsContainer.addSubview(previousButton)
        centerControlsContainer.addSubview(playPauseButton)
        centerControlsContainer.addSubview(nextButton)

        bottomControlsContainer = UIView()
        bottomControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomControlsContainer.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        controlsContainer.addSubview(bottomControlsContainer)
        progressSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(videoProgressTouchDown), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(videoProgressTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        progressSlider.minimumTrackTintColor = .systemPurple
        progressSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressSlider.setThumbImage(UIImage(), for: .normal)
        progressSlider.setThumbImage(UIImage(), for: .highlighted)
        currentTimeLabel.font = AppTypography.time
        currentTimeLabel.textColor = .white
        currentTimeLabel.text = AppStrings.timeZero
        currentTimeLabel.fitTextWithinBounds(multiline: false)
        remainingTimeLabel.font = AppTypography.time
        remainingTimeLabel.textColor = .white
        remainingTimeLabel.text = AppStrings.timeMinusZero
        remainingTimeLabel.fitTextWithinBounds(multiline: false)
        let playNextOffImg = (UIImage(named: "play-next-off"))?.withRenderingMode(.alwaysOriginal)
        let playNextOnImg = (UIImage(named: "play-next-on"))?.withRenderingMode(.alwaysOriginal)
        playNextButton.setImage(imageResizedTo(CGSize(width: 37, height: 25), playNextOffImg), for: .normal)
        playNextButton.setImage(imageResizedTo(CGSize(width: 37, height: 25), playNextOnImg), for: .selected)
        playNextButton.addTarget(self, action: #selector(tapPlayNext), for: .touchUpInside)
        playNextButton.isSelected = false
        pipButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(named: "PiP")), for: .normal)
        pipButton.tintColor = .white
        pipButton.addTarget(self, action: #selector(tapPiP), for: .touchUpInside)
        subtitlesButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(named: "subtitles-off")), for: .normal)
        subtitlesButton.tintColor = .white
        subtitlesButton.addTarget(self, action: #selector(tapSubtitles), for: .touchUpInside)
        audioTrackButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(systemName: "speaker.wave.2")), for: .normal)
        audioTrackButton.tintColor = .white
        audioTrackButton.addTarget(self, action: #selector(tapAudioTrack), for: .touchUpInside)
        speedButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(named: "speed-1.0x")), for: .normal)
        speedButton.tintColor = .white
        speedButton.addTarget(self, action: #selector(tapSpeed), for: .touchUpInside)
        lockButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(named: "unlock")), for: .normal)
        lockButton.tintColor = .white
        lockButton.addTarget(self, action: #selector(tapLock), for: .touchUpInside)
        rotateButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(named: "rotate")), for: .normal)
        rotateButton.tintColor = .white
        rotateButton.addTarget(self, action: #selector(tapRotate), for: .touchUpInside)
        shuffleButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(named: "Shuffle")), for: .normal)
        shuffleButton.tintColor = .white
        shuffleButton.addTarget(self, action: #selector(tapShuffle), for: .touchUpInside)
        [progressSlider, currentTimeLabel, remainingTimeLabel, playNextButton, pipButton, subtitlesButton, audioTrackButton, speedButton, lockButton, rotateButton, shuffleButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        let progressRow = UIStackView(arrangedSubviews: [currentTimeLabel, progressSlider, remainingTimeLabel])
        progressRow.axis = .horizontal
        progressRow.spacing = 8
        progressRow.alignment = .center
        progressRow.translatesAutoresizingMaskIntoConstraints = false
        currentTimeLabel.setContentHuggingPriority(.required, for: .horizontal)
        remainingTimeLabel.setContentHuggingPriority(.required, for: .horizontal)
        let progressArea = UIView()
        progressArea.translatesAutoresizingMaskIntoConstraints = false
        progressArea.addSubview(playNextButton)
        progressArea.addSubview(progressRow)
        bottomControlsContainer.addSubview(progressArea)
        let bottomRow = UIStackView(arrangedSubviews: [lockButton, rotateButton, pipButton, subtitlesButton, audioTrackButton, speedButton, shuffleButton])
        bottomRow.axis = .horizontal
        bottomRow.distribution = .equalSpacing
        bottomRow.spacing = 8
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        bottomControlsContainer.addSubview(bottomRow)
        NSLayoutConstraint.activate([
            playNextButton.topAnchor.constraint(equalTo: progressArea.topAnchor),
            playNextButton.trailingAnchor.constraint(equalTo: progressArea.trailingAnchor),
            playNextButton.widthAnchor.constraint(equalToConstant: 37),
            playNextButton.heightAnchor.constraint(equalToConstant: 25),
            progressRow.leadingAnchor.constraint(equalTo: progressArea.leadingAnchor),
            progressRow.trailingAnchor.constraint(equalTo: progressArea.trailingAnchor),
            progressRow.bottomAnchor.constraint(equalTo: progressArea.bottomAnchor),
            progressRow.topAnchor.constraint(equalTo: playNextButton.bottomAnchor, constant: 4)
        ])

        volumeSliderPanel.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        volumeSliderPanel.layer.cornerRadius = 8
        volumeSliderPanel.isHidden = true
        volumeSliderPanel.translatesAutoresizingMaskIntoConstraints = true
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = PlayerService.shared.volume
        volumeSlider.isContinuous = true
        volumeSlider.minimumTrackTintColor = .systemPurple
        volumeSlider.addTarget(self, action: #selector(volumeSliderChanged), for: .valueChanged)
        volumeSlider.addTarget(self, action: #selector(volumeSliderTouchDown), for: .touchDown)
        volumeSlider.addTarget(self, action: #selector(volumeSliderTouchCancelledOrEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        volumeSlider.addTarget(self, action: #selector(volumeSliderDragged), for: [.touchDragInside, .touchDragOutside])
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        volumeSliderPanel.addSubview(volumeSlider)
        controlsContainer.addSubview(volumeSliderPanel)
        NSLayoutConstraint.activate([
            volumeSlider.centerXAnchor.constraint(equalTo: volumeSliderPanel.centerXAnchor),
            volumeSlider.centerYAnchor.constraint(equalTo: volumeSliderPanel.centerYAnchor),
            volumeSlider.widthAnchor.constraint(equalToConstant: 120),
            volumeSlider.heightAnchor.constraint(equalToConstant: 28)
        ])
        unlockOverlay.backgroundColor = .clear
        unlockOverlay.isHidden = true
        unlockOverlay.isUserInteractionEnabled = true
        view.addSubview(unlockOverlay)
        unlockOverlay.translatesAutoresizingMaskIntoConstraints = false
        overlayLockButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(named: "lock")), for: .normal)
        overlayLockButton.tintColor = .white
        overlayLockButton.translatesAutoresizingMaskIntoConstraints = false
        overlayLockButton.addTarget(self, action: #selector(tapOverlayLock), for: .touchUpInside)
        unlockOverlay.addSubview(overlayLockButton)
        let overlayTap = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        unlockOverlay.addGestureRecognizer(overlayTap)
        let overlayPan = UIPanGestureRecognizer(target: self, action: #selector(handleBrightnessOrSeekPan(_:)))
        unlockOverlay.addGestureRecognizer(overlayPan)
        setupBrightnessOverlay()

        topBarTopToSafeArea = topBarContainer.topAnchor.constraint(equalTo: controlsContainer.safeAreaLayoutGuide.topAnchor)
        topBarTopToView = topBarContainer.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 28)
        topBarHeightConstraint = topBarContainer.heightAnchor.constraint(equalToConstant: 44)
        let topBarInsetVideo: CGFloat = 12
        backButtonLeadingConstraint = backButton.leadingAnchor.constraint(equalTo: topBarContainer.safeAreaLayoutGuide.leadingAnchor, constant: topBarInsetVideo)
        castButtonTrailingConstraint = castButton.trailingAnchor.constraint(equalTo: topBarContainer.safeAreaLayoutGuide.trailingAnchor, constant: -topBarInsetVideo)
        NSLayoutConstraint.activate([
            topBarTopToSafeArea!,
            topBarContainer.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            topBarContainer.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            topBarHeightConstraint!,
            backButtonLeadingConstraint!,
            backButton.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 24),
            backButton.heightAnchor.constraint(equalToConstant: 24),
            titleMarqueeContainer.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            titleMarqueeContainer.trailingAnchor.constraint(equalTo: volumeButton.leadingAnchor, constant: -12),
            titleMarqueeContainer.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            titleMarqueeContainer.heightAnchor.constraint(equalToConstant: 24),
            titleMarqueeContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            titleLabel.centerXAnchor.constraint(equalTo: topBarContainer.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleMarqueeContainer.centerYAnchor),
            castButtonTrailingConstraint!,
            castButton.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            castButton.widthAnchor.constraint(equalToConstant: 24),
            castButton.heightAnchor.constraint(equalToConstant: 24),
            volumeButton.trailingAnchor.constraint(equalTo: castButton.leadingAnchor, constant: -12),
            volumeButton.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            volumeButton.widthAnchor.constraint(equalToConstant: 24),
            volumeButton.heightAnchor.constraint(equalToConstant: 24),
            centerControlsContainer.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            centerControlsContainer.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            centerControlsContainer.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            centerControlsContainer.heightAnchor.constraint(equalToConstant: 80),
            previousButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -24),
            previousButton.centerYAnchor.constraint(equalTo: centerControlsContainer.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 43),
            previousButton.heightAnchor.constraint(equalToConstant: 43),
            playPauseButton.centerXAnchor.constraint(equalTo: centerControlsContainer.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: centerControlsContainer.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 69),
            playPauseButton.heightAnchor.constraint(equalToConstant: 69),
            nextButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 24),
            nextButton.centerYAnchor.constraint(equalTo: centerControlsContainer.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 43),
            nextButton.heightAnchor.constraint(equalToConstant: 43),
            bottomControlsContainer.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            bottomControlsContainer.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            bottomControlsContainer.bottomAnchor.constraint(equalTo: controlsContainer.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            progressArea.topAnchor.constraint(equalTo: bottomControlsContainer.topAnchor, constant: 10),
            progressArea.leadingAnchor.constraint(equalTo: bottomControlsContainer.leadingAnchor, constant: 16),
            progressArea.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor, constant: -16),
            bottomRow.topAnchor.constraint(equalTo: progressArea.bottomAnchor, constant: 12),
            bottomRow.leadingAnchor.constraint(equalTo: bottomControlsContainer.leadingAnchor, constant: 16),
            bottomRow.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor, constant: -16),
            bottomRow.bottomAnchor.constraint(equalTo: bottomControlsContainer.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            pipButton.widthAnchor.constraint(equalToConstant: 25),
            pipButton.heightAnchor.constraint(equalToConstant: 25),
            speedButton.widthAnchor.constraint(equalToConstant: 25),
            speedButton.heightAnchor.constraint(equalToConstant: 25),
            lockButton.widthAnchor.constraint(equalToConstant: 25),
            lockButton.heightAnchor.constraint(equalToConstant: 25),
            rotateButton.widthAnchor.constraint(equalToConstant: 25),
            rotateButton.heightAnchor.constraint(equalToConstant: 25),
            subtitlesButton.widthAnchor.constraint(equalToConstant: 25),
            subtitlesButton.heightAnchor.constraint(equalToConstant: 25),
            audioTrackButton.widthAnchor.constraint(equalToConstant: 25),
            audioTrackButton.heightAnchor.constraint(equalToConstant: 25),
            shuffleButton.widthAnchor.constraint(equalToConstant: 25),
            shuffleButton.heightAnchor.constraint(equalToConstant: 25),
            controlsContainer.topAnchor.constraint(equalTo: view.topAnchor),
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            unlockOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            unlockOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            unlockOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            unlockOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayLockButton.centerXAnchor.constraint(equalTo: unlockOverlay.centerXAnchor),
            overlayLockButton.bottomAnchor.constraint(equalTo: unlockOverlay.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            overlayLockButton.widthAnchor.constraint(equalToConstant: 25),
            overlayLockButton.heightAnchor.constraint(equalToConstant: 25)
        ])
        setupAudioUI()
    }

    private func setupBrightnessOverlay() {
        brightnessOverlayLabel.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        brightnessOverlayLabel.layer.cornerRadius = 16
        brightnessOverlayLabel.clipsToBounds = true
        brightnessOverlayLabel.font = AppFonts.semibold(18)
        brightnessOverlayLabel.textColor = .white
        brightnessOverlayLabel.textAlignment = .center
        brightnessOverlayLabel.alpha = 0
        brightnessOverlayLabel.isUserInteractionEnabled = false
        brightnessOverlayLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(brightnessOverlayLabel)
        NSLayoutConstraint.activate([
            brightnessOverlayLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            brightnessOverlayLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            brightnessOverlayLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            brightnessOverlayLabel.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func setupAudioUI() {
        audioContainerView = UIView()
        audioContainerView.translatesAutoresizingMaskIntoConstraints = false
        audioContainerView.backgroundColor = .clear
        audioContainerView.isHidden = true
        controlsContainer.addSubview(audioContainerView)

        albumArtImageView.layer.cornerRadius = 5
        audioContainerView.addSubview(albumArtImageView)

        audioTitleLabel.text = AppStrings.dash
        audioTitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        audioContainerView.addSubview(audioTitleLabel)
        audioSubtitleLabel.text = AppStrings.dash
        audioSubtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        audioContainerView.addSubview(audioSubtitleLabel)

        audioProgressSlider.minimumValue = 0
        audioProgressSlider.maximumValue = 1
        audioProgressSlider.minimumTrackTintColor = .systemPurple
        audioProgressSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        let thumbSize: CGFloat = 14
        let thumbImg = UIGraphicsImageRenderer(size: CGSize(width: thumbSize, height: thumbSize)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: thumbSize, height: thumbSize))
        }
        audioProgressSlider.setThumbImage(thumbImg, for: .normal)
        audioProgressSlider.setThumbImage(thumbImg, for: .highlighted)
        audioProgressSlider.addTarget(self, action: #selector(audioSliderChanged), for: .valueChanged)
        audioProgressSlider.addTarget(self, action: #selector(audioProgressTouchDown), for: .touchDown)
        audioProgressSlider.addTarget(self, action: #selector(audioProgressTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        audioProgressSlider.translatesAutoresizingMaskIntoConstraints = false
        audioProgressSlider.setContentCompressionResistancePriority(.required, for: .vertical)

        audioCurrentTimeLabel.font = AppTypography.time
        audioCurrentTimeLabel.textColor = .white
        audioCurrentTimeLabel.text = AppStrings.timeZero
        audioCurrentTimeLabel.fitTextWithinBounds(multiline: false)
        audioRemainingTimeLabel.font = AppTypography.time
        audioRemainingTimeLabel.textColor = .white
        audioRemainingTimeLabel.text = AppStrings.timeMinusZero
        audioRemainingTimeLabel.fitTextWithinBounds(multiline: false)
        [audioCurrentTimeLabel, audioRemainingTimeLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        audioCurrentTimeLabel.setContentHuggingPriority(.required, for: .horizontal)
        audioRemainingTimeLabel.setContentHuggingPriority(.required, for: .horizontal)

        [audioShuffleButton, audioPrevButton, audioNextButton, audioRepeatButton].forEach { b in
            b.backgroundColor = .clear
            b.tintColor = .white
            b.layer.cornerRadius = 0
        }
        audioShuffleButton.setImage(imageResizedTo(CGSize(width: 24, height: 24), UIImage(named: "randomize") ?? UIImage(named: "Shuffle")), for: .normal)
        audioShuffleButton.addTarget(self, action: #selector(tapAudioShuffle), for: .touchUpInside)
        audioPrevButton.setImage(imageResizedTo(CGSize(width: 24, height: 24), UIImage(named: "back 1") ?? UIImage(named: "prev")), for: .normal)
        audioPrevButton.addTarget(self, action: #selector(tapPrevious), for: .touchUpInside)
        audioPlayPauseButton.backgroundColor = .clear
        audioPlayPauseButton.tintColor = .white
        audioPlayPauseButton.layer.cornerRadius = 35
        audioPlayPauseButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        audioPlayPauseButton.setContentHuggingPriority(.defaultHigh, for: .vertical)
        audioPlayPauseButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        audioPlayPauseButton.setContentCompressionResistancePriority(.required, for: .vertical)
        let pauseImg = (UIImage(named: "audio-pause") ?? UIImage(named: "pause"))?.withRenderingMode(.alwaysOriginal)
        audioPlayPauseButton.setImage(imageResizedTo(CGSize(width: 70, height: 70), pauseImg), for: .normal)
        audioPlayPauseButton.addTarget(self, action: #selector(tapPlayPause), for: .touchUpInside)
        audioNextButton.setImage(imageResizedTo(CGSize(width: 24, height: 24), UIImage(named: "next 1") ?? UIImage(named: "next")), for: .normal)
        audioNextButton.addTarget(self, action: #selector(tapNext), for: .touchUpInside)
        updateAudioRepeatButtonImage()
        audioRepeatButton.addTarget(self, action: #selector(tapAudioRepeat), for: .touchUpInside)
        [audioShuffleButton, audioPrevButton, audioPlayPauseButton, audioNextButton, audioRepeatButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let playPauseContainer = UIView()
        playPauseContainer.translatesAutoresizingMaskIntoConstraints = false
        playPauseContainer.backgroundColor = .clear
        playPauseContainer.setContentHuggingPriority(.required, for: .horizontal)
        playPauseContainer.setContentHuggingPriority(.required, for: .vertical)
        playPauseContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        playPauseContainer.setContentCompressionResistancePriority(.required, for: .vertical)
        playPauseContainer.addSubview(audioPlayPauseButton)

        let buttonsRow = UIStackView(arrangedSubviews: [audioShuffleButton, audioPrevButton, playPauseContainer, audioNextButton, audioRepeatButton])
        buttonsRow.axis = .horizontal
        buttonsRow.distribution = .equalSpacing
        buttonsRow.alignment = .center
        buttonsRow.spacing = 8
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false

        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.backgroundColor = .clear
        audioContainerView.addSubview(progressContainer)
        audioContainerView.addSubview(buttonsRow)

        let isPad = traitCollection.userInterfaceIdiom == .pad
        let albumArtHorizontalInset: CGFloat = 94
        let progressStackHorizontalInset: CGFloat
        let buttonsRowHorizontalInset: CGFloat
        let titleHorizontalInset: CGFloat
        let titleTopFromCover: CGFloat
        let progressBlockTopFromTitle: CGFloat
        if isPad {
            progressStackHorizontalInset = 74
            buttonsRowHorizontalInset = 74
            titleHorizontalInset = albumArtHorizontalInset
            titleTopFromCover = 16
            progressBlockTopFromTitle = 26
        } else {
            let screenHeight = UIScreen.main.bounds.height
            let refMin: CGFloat = 667
            let refMax: CGFloat = 932
            let t = min(1, max(0, (screenHeight - refMin) / (refMax - refMin)))
            func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
            let horizontalInset = lerp(28, 24)
            progressStackHorizontalInset = horizontalInset
            buttonsRowHorizontalInset = horizontalInset
            titleHorizontalInset = horizontalInset
            titleTopFromCover = lerp(10, 26)
            progressBlockTopFromTitle = lerp(24, 68)
        }
        let albumArtConstraints: [NSLayoutConstraint]
        let progressConstraints: [NSLayoutConstraint]
        if isPad {
            let timesRow = UIStackView(arrangedSubviews: [audioCurrentTimeLabel, audioRemainingTimeLabel])
            timesRow.axis = .horizontal
            timesRow.distribution = .equalSpacing
            timesRow.alignment = .center
            timesRow.translatesAutoresizingMaskIntoConstraints = false
            let sliderOnlyStack = UIStackView(arrangedSubviews: [audioProgressSlider])
            sliderOnlyStack.axis = .vertical
            sliderOnlyStack.alignment = .fill
            sliderOnlyStack.translatesAutoresizingMaskIntoConstraints = false
            progressContainer.addSubview(sliderOnlyStack)
            audioContainerView.addSubview(timesRow)
            albumArtConstraints = [
                albumArtImageView.topAnchor.constraint(equalTo: audioContainerView.topAnchor, constant: 16),
                albumArtImageView.leadingAnchor.constraint(equalTo: audioContainerView.leadingAnchor, constant: albumArtHorizontalInset),
                albumArtImageView.trailingAnchor.constraint(equalTo: audioContainerView.trailingAnchor, constant: -albumArtHorizontalInset),
                albumArtImageView.heightAnchor.constraint(equalTo: albumArtImageView.widthAnchor),
                audioTitleLabel.leadingAnchor.constraint(equalTo: audioContainerView.leadingAnchor, constant: titleHorizontalInset),
                audioTitleLabel.trailingAnchor.constraint(equalTo: audioContainerView.trailingAnchor, constant: -titleHorizontalInset),
                audioSubtitleLabel.leadingAnchor.constraint(equalTo: audioContainerView.leadingAnchor, constant: titleHorizontalInset),
                audioSubtitleLabel.trailingAnchor.constraint(equalTo: audioContainerView.trailingAnchor, constant: -titleHorizontalInset)
            ]
            let progressTop = progressContainer.topAnchor.constraint(equalTo: audioSubtitleLabel.bottomAnchor, constant: 227)
            progressTop.priority = .defaultHigh
            progressConstraints = [
                progressTop,
                progressContainer.topAnchor.constraint(greaterThanOrEqualTo: audioSubtitleLabel.bottomAnchor, constant: 99),
                progressContainer.bottomAnchor.constraint(equalTo: buttonsRow.topAnchor, constant: -30),
                sliderOnlyStack.topAnchor.constraint(equalTo: progressContainer.topAnchor),
                sliderOnlyStack.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor, constant: progressStackHorizontalInset),
                sliderOnlyStack.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor, constant: -progressStackHorizontalInset),
                sliderOnlyStack.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
                timesRow.topAnchor.constraint(equalTo: audioSubtitleLabel.bottomAnchor, constant: 226),
                timesRow.leadingAnchor.constraint(equalTo: audioContainerView.leadingAnchor, constant: progressStackHorizontalInset),
                timesRow.trailingAnchor.constraint(equalTo: audioContainerView.trailingAnchor, constant: -progressStackHorizontalInset),
                buttonsRow.bottomAnchor.constraint(equalTo: audioContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -36)
            ]
        } else {
            let screenHeight = UIScreen.main.bounds.height
            let refMin: CGFloat = 667
            let refMax: CGFloat = 932
            let t = min(1, max(0, (screenHeight - refMin) / (refMax - refMin)))
            func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
            let coverTop = lerp(10, 26)
            let horizontalInset = lerp(28, 24)
            let sliderHeight = lerp(14, 20)
            let progressGap = lerp(4, 6)
            let timeRowHeight = lerp(16, 20)
            let progressBlockHeight = sliderHeight + progressGap + timeRowHeight
            let buttonsTopBelowProgress = lerp(24, 68)
            let bottomInsetPhone = lerp(20, 36)

            let timesRowPhone = UIStackView(arrangedSubviews: [audioCurrentTimeLabel, audioRemainingTimeLabel])
            timesRowPhone.axis = .horizontal
            timesRowPhone.distribution = .equalSpacing
            timesRowPhone.alignment = .center
            timesRowPhone.translatesAutoresizingMaskIntoConstraints = false
            let progressStackPhone = UIStackView(arrangedSubviews: [audioProgressSlider, timesRowPhone])
            progressStackPhone.axis = .vertical
            progressStackPhone.alignment = .fill
            progressStackPhone.spacing = progressGap
            progressStackPhone.distribution = .fill
            progressStackPhone.translatesAutoresizingMaskIntoConstraints = false
            progressContainer.addSubview(progressStackPhone)
            albumArtConstraints = [
                albumArtImageView.topAnchor.constraint(equalTo: audioContainerView.topAnchor, constant: coverTop),
                albumArtImageView.leadingAnchor.constraint(equalTo: audioContainerView.leadingAnchor, constant: horizontalInset),
                albumArtImageView.trailingAnchor.constraint(equalTo: audioContainerView.trailingAnchor, constant: -horizontalInset),
                albumArtImageView.heightAnchor.constraint(equalTo: albumArtImageView.widthAnchor),
                audioTitleLabel.leadingAnchor.constraint(equalTo: audioContainerView.leadingAnchor, constant: horizontalInset),
                audioTitleLabel.trailingAnchor.constraint(equalTo: audioContainerView.trailingAnchor, constant: -horizontalInset),
                audioSubtitleLabel.leadingAnchor.constraint(equalTo: audioContainerView.leadingAnchor, constant: horizontalInset),
                audioSubtitleLabel.trailingAnchor.constraint(equalTo: audioContainerView.trailingAnchor, constant: -horizontalInset)
            ]
            let buttonsRowBottom = buttonsRow.bottomAnchor.constraint(equalTo: audioContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -bottomInsetPhone)
            buttonsRowBottom.priority = UILayoutPriority(999)
            progressConstraints = [
                progressContainer.topAnchor.constraint(equalTo: audioSubtitleLabel.bottomAnchor, constant: progressBlockTopFromTitle),
                progressContainer.heightAnchor.constraint(equalToConstant: progressBlockHeight),
                progressStackPhone.topAnchor.constraint(equalTo: progressContainer.topAnchor),
                progressStackPhone.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor, constant: horizontalInset),
                progressStackPhone.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor, constant: -horizontalInset),
                progressStackPhone.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
                audioProgressSlider.heightAnchor.constraint(equalToConstant: sliderHeight),
                buttonsRow.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: buttonsTopBelowProgress),
                buttonsRowBottom
            ]
        }
        let commonConstraints: [NSLayoutConstraint] = [
            audioContainerView.topAnchor.constraint(equalTo: topBarContainer.bottomAnchor),
            audioContainerView.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            audioContainerView.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            audioContainerView.bottomAnchor.constraint(equalTo: controlsContainer.safeAreaLayoutGuide.bottomAnchor),
            audioTitleLabel.topAnchor.constraint(equalTo: albumArtImageView.bottomAnchor, constant: titleTopFromCover),
            audioSubtitleLabel.topAnchor.constraint(equalTo: audioTitleLabel.bottomAnchor, constant: 4),
            progressContainer.leadingAnchor.constraint(equalTo: audioContainerView.leadingAnchor),
            progressContainer.trailingAnchor.constraint(equalTo: audioContainerView.trailingAnchor),
            buttonsRow.leadingAnchor.constraint(equalTo: audioContainerView.leadingAnchor, constant: buttonsRowHorizontalInset),
            buttonsRow.trailingAnchor.constraint(equalTo: audioContainerView.trailingAnchor, constant: -buttonsRowHorizontalInset),
            playPauseContainer.widthAnchor.constraint(equalToConstant: 70),
            playPauseContainer.heightAnchor.constraint(equalToConstant: 70),
            audioPlayPauseButton.centerXAnchor.constraint(equalTo: playPauseContainer.centerXAnchor),
            audioPlayPauseButton.centerYAnchor.constraint(equalTo: playPauseContainer.centerYAnchor),
            audioPlayPauseButton.widthAnchor.constraint(equalToConstant: 70),
            audioPlayPauseButton.heightAnchor.constraint(equalToConstant: 70),
            audioShuffleButton.widthAnchor.constraint(equalToConstant: 32),
            audioShuffleButton.heightAnchor.constraint(equalToConstant: 32),
            audioPrevButton.widthAnchor.constraint(equalToConstant: 32),
            audioPrevButton.heightAnchor.constraint(equalToConstant: 32),
            audioNextButton.widthAnchor.constraint(equalToConstant: 32),
            audioNextButton.heightAnchor.constraint(equalToConstant: 32),
            audioRepeatButton.widthAnchor.constraint(equalToConstant: 32),
            audioRepeatButton.heightAnchor.constraint(equalToConstant: 32)
        ]
        NSLayoutConstraint.activate(commonConstraints + albumArtConstraints + progressConstraints)
    }

    private func updateAudioRepeatButtonImage(mode: PlaybackMode = PlayerService.shared.playbackMode) {
        let img: UIImage?
        switch mode {
        case .repeatOne:
            img = (UIImage(named: "repeat-1") ?? UIImage(systemName: "repeat.1", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)))?.withRenderingMode(.alwaysTemplate)
        case .repeatAll, .shuffle, .stopAfterCurrent:
            img = (UIImage(named: "repeat") ?? UIImage(systemName: "repeat", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)))?.withRenderingMode(.alwaysTemplate)
        }
        audioRepeatButton.setImage(imageResizedTo(CGSize(width: 24, height: 24), img), for: .normal)
        audioRepeatButton.tintColor = (mode == .repeatOne || mode == .repeatAll) ? .systemPurple : .white
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleBrightnessOrSeekPan(_:)))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        view.addGestureRecognizer(pan)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        longPress.delegate = self
        view.addGestureRecognizer(longPress)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(_:)))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    private func scheduleControlsHide() {
        guard !isUILocked, !isAudioMode else { return }
        controlsHideTimer?.invalidate()
        controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.hideControlsAnimated()
        }
        controlsHideTimer?.tolerance = 0.2
    }

    private func hideControlsAnimated() {
        guard controlsVisible, !isUILocked, !isAudioMode else { return }
        controlsVisible = false
        volumeSliderPanel.isHidden = true
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) { [weak self] in
            self?.controlsContainer.alpha = 0
        } completion: { [weak self] _ in
            self?.controlsContainer.isUserInteractionEnabled = false
        }
    }

    private func showControlsAnimated() {
        guard !controlsVisible, !isUILocked else { return }
        controlsVisible = true
        controlsContainer.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) { [weak self] in
            self?.controlsContainer.alpha = 1
        } completion: { [weak self] _ in
            if self?.isAudioMode == false { self?.scheduleControlsHide() }
        }
    }

    private func resetControlsHideTimer() {
        guard !isUILocked else { return }
        if controlsVisible {
            scheduleControlsHide()
        } else {
            showControlsAnimated()
        }
    }

    @objc private func handleScreenTap(_ gesture: UITapGestureRecognizer) {
        if isUILocked { return }
        if CACurrentMediaTime() < suppressScreenTapUntil { return }
        if controlsVisible {
            hideControlsAnimated()
        } else {
            showControlsAnimated()
        }
    }

    @objc private func handleBrightnessOrSeekPan(_ g: UIPanGestureRecognizer) {
        guard !isAudioMode else { return }
        let translation = g.translation(in: view)

        switch g.state {
        case .began:
            activePanDirection = nil
            if !isUILocked { resetControlsHideTimer() }
            brightnessGestureStart = UIScreen.main.brightness
            let duration = PlayerService.shared.duration
            panStartProgress = duration > 0 ? PlayerService.shared.currentTime / duration : 0
        case .changed:
            if hypot(translation.x, translation.y) > 6 {
                suppressScreenTapUntil = CACurrentMediaTime() + 0.2
            }
            if activePanDirection == nil {
                activePanDirection = abs(translation.y) >= abs(translation.x) ? .brightness : .seek
            }
            guard let direction = activePanDirection else { return }
            switch direction {
            case .brightness:
                let delta = -translation.y / 300
                var newVal = brightnessGestureStart + CGFloat(delta)
                newVal = max(0, min(1, newVal))
                UIScreen.main.brightness = newVal
                presenter?.didChangeBrightness(Float(newVal))
                showBrightnessOverlay(newVal)
            case .seek:
                let width = view.bounds.width
                guard width > 0 else { return }
                let delta = Double(translation.x) / Double(width)
                var progress = panStartProgress + delta
                progress = max(0, min(1, progress))
                isPanSeekInProgress = true
                panSeekLastProgress = progress
                progressSlider.value = Float(progress)
                applyLocalProgressPreview(progress: progress)
            }
        case .ended, .cancelled:
            if hypot(translation.x, translation.y) > 6 {
                suppressScreenTapUntil = CACurrentMediaTime() + 0.2
            }
            if activePanDirection == .seek {
                isPanSeekInProgress = false
                presenter?.didSeek(to: panSeekLastProgress)
            } else if activePanDirection == .brightness {
                scheduleBrightnessOverlayHide()
            }
            activePanDirection = nil
        default:
            break
        }
    }

    private func showBrightnessOverlay(_ value: CGFloat) {
        let percent = max(0, min(100, Int(round(value * 100))))
        brightnessOverlayLabel.text = AppStrings.brightnessValue(percent: percent)
        brightnessOverlayHideWorkItem?.cancel()
        brightnessOverlayLabel.layer.removeAllAnimations()
        brightnessOverlayLabel.alpha = 1
        scheduleBrightnessOverlayHide(delay: 0.7)
    }

    private func scheduleBrightnessOverlayHide(delay: TimeInterval = 0.35) {
        brightnessOverlayHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self?.brightnessOverlayLabel.alpha = 0
            }
        }
        brightnessOverlayHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        if isUILocked { return }
        if g.state == .began {
            speedBeforeHold = PlayerService.shared.speed
            holdSpeedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.presenter?.didChangeSpeed(.double)
            }
        } else if g.state == .ended || g.state == .cancelled {
            holdSpeedTimer?.invalidate()
            holdSpeedTimer = nil
            presenter?.didChangeSpeed(speedBeforeHold)
        }
    }

    @objc private func videoProgressTouchDown() {
        isVideoScrubbing = true
        resetControlsHideTimer()
    }

    @objc private func videoProgressTouchUp() {
        isVideoScrubbing = false
        presenter?.didSeek(to: Double(progressSlider.value))
    }

    @objc private func sliderChanged() {
        resetControlsHideTimer()
        if isVideoScrubbing {
            applyLocalProgressPreview(progress: Double(progressSlider.value))
        }
    }

    @objc private func audioProgressTouchDown() {
        isAudioScrubbing = true
        resetControlsHideTimer()
    }

    @objc private func audioProgressTouchUp() {
        isAudioScrubbing = false
        presenter?.didSeek(to: Double(audioProgressSlider.value))
    }

    @objc private func audioSliderChanged() {
        resetControlsHideTimer()
        if isAudioScrubbing {
            applyLocalAudioProgressPreview(progress: Double(audioProgressSlider.value))
        }
    }

    private func applyLocalProgressPreview(progress: Double) {
        let duration = PlayerService.shared.duration
        guard duration > 0 else { return }
        let current = progress * duration
        let remaining = max(0, duration - current)
        currentTimeLabel.text = formatTime(current)
        remainingTimeLabel.text = "-" + formatTime(remaining)
    }

    private func applyLocalAudioProgressPreview(progress: Double) {
        let duration = PlayerService.shared.duration
        guard duration > 0 else { return }
        let current = progress * duration
        let remaining = max(0, duration - current)
        audioCurrentTimeLabel.text = formatTime(current)
        audioRemainingTimeLabel.text = "-" + formatTime(remaining)
    }

    @objc private func tapAudioShuffle() {
        resetControlsHideTimer()
        presenter?.didTapShuffle(isAudioMode: true)
    }

    @objc private func tapAudioRepeat() {
        resetControlsHideTimer()
        presenter?.didTapRepeat()
    }

    @objc private func sliderTouchEnd() {
    }

    @objc private func tapPlayPause() {
        resetControlsHideTimer()
        presenter?.didTapPlayPause()
    }

    @objc private func tapNext() {
        resetControlsHideTimer()
        presenter?.didTapNext()
    }

    @objc private func tapPrevious() {
        resetControlsHideTimer()
        presenter?.didTapPrevious()
    }

    @objc private func tapSpeed() {
        resetControlsHideTimer()
        presenter?.didTapSpeed()
    }

    @objc private func tapPlayNext() {
        resetControlsHideTimer()
        playNextOn.toggle()
        presenter?.didSetAutoplay(playNextOn)
        updatePlayNextButtonImage()
    }

    private func updatePlayNextButtonImage() {
        let offImg = (UIImage(named: "play-next-off"))?.withRenderingMode(.alwaysOriginal)
        let onImg = (UIImage(named: "play-next-on"))?.withRenderingMode(.alwaysOriginal)
        playNextButton.setImage(imageResizedTo(CGSize(width: 37, height: 25), offImg), for: .normal)
        playNextButton.setImage(imageResizedTo(CGSize(width: 37, height: 25), onImg), for: .selected)
        playNextButton.isSelected = playNextOn
    }

    @objc private func tapShuffle() {
        resetControlsHideTimer()
        presenter?.didTapShuffle(isAudioMode: false)
    }

    @objc private func tapPiP() {
        resetControlsHideTimer()
        guard !isAudioMode else { return }
        if PlayerService.shared.isVideoPlayedWithVLC {
            useStoredPipConversionOrShowUnavailable()
            return
        }
        setupPiPIfNeeded()
        guard let pip = pipController as? AVPictureInPictureController else {
            showPiPUnavailableAlert()
            return
        }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else if pip.isPictureInPicturePossible {
            pip.startPictureInPicture()
        } else {
            tryStartPiPWhenPossible()
        }
    }

    private func useStoredPipConversionOrShowUnavailable() {
        guard let item = PlayerService.shared.currentMediaItem else { return }
        if item.url.isFileURL {
            let parent = item.url.deletingLastPathComponent()
            if parent.lastPathComponent == "Media",
               let pipURL = MediaStorageService.shared.resolvePipConversionURL(itemId: item.id, mediaDirectory: parent) {
                pipWaitingForItemId = nil
                beginPipSwitchToStoredMP4(pipURL: pipURL, item: item)
                return
            }
        }
        if let stored = MediaStorageService.shared.mediaItem(byId: item.id), stored.pipPreparation == .pending {
            pipWaitingForItemId = item.id
            showPiPUnavailableAlert(reason: AppStrings.pipPreparingTryLater)
            return
        }
        if let stored = MediaStorageService.shared.mediaItem(byId: item.id), stored.pipPreparation == .failed {
            showPiPUnavailableAlert(reason: AppStrings.libraryPipConversionErrorShort)
            return
        }
        showPiPUnavailableAlert(reason: AppStrings.pipNotAvailableAddAgain)
    }

    private func beginPipSwitchToStoredMP4(pipURL: URL, item: MediaItem) {
        let seekTime = MediaStorageService.shared.loadLastPlayback().flatMap { $0.itemId == item.id ? $0.time : nil } ?? 0
        PlayerService.shared.switchToTranscodedMP4ForPiP(tempMP4URL: pipURL, seekTime: seekTime) { [weak self] in
            guard let self = self else { return }
            self.playerLayer?.player = PlayerService.shared.currentPlayer
            self.playerLayer?.frame = self.view.bounds
            self.playerLayer?.layoutIfNeeded()
            PlayerService.shared.setVideoDrawable(nil)
            self.setupPiPIfNeeded()
            guard let pip = self.pipController as? AVPictureInPictureController else {
                self.showPiPUnavailableAlert(reason: AppStrings.pipNotReady)
                return
            }
            if pip.isPictureInPicturePossible {
                pip.startPictureInPicture()
            } else {
                self.tryStartPiPWhenPossible()
            }
        }
    }

    private func handlePipConversionFinishedNotification(_ note: Notification) {
        guard let itemId = note.userInfo?["itemId"] as? String,
              let ok = note.userInfo?["success"] as? Bool else { return }
        guard pipWaitingForItemId == itemId else { return }
        pipWaitingForItemId = nil
        if ok {
            useStoredPipConversionOrShowUnavailable()
        } else {
            showPiPUnavailableAlert(reason: AppStrings.libraryPipConversionErrorShort)
        }
    }

    private func showPiPUnavailableAlert(reason: String? = nil) {
        let supported = AVPictureInPictureController.isPictureInPictureSupported()
        let message: String
        if let reason = reason, !reason.isEmpty {
            message = reason
        } else if !supported {
            message = AppStrings.pipNotSupportedDevice
        } else {
            message = AppStrings.pipNotReady
        }
        let alert = UIAlertController(
            title: AppStrings.pictureInPicture,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: AppStrings.ok, style: .default))
        present(alert, animated: true)
    }

    private func tryStartPiPWhenPossible() {
        guard pipController is AVPictureInPictureController else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.setupPiPIfNeeded()
            if let p = self.pipController as? AVPictureInPictureController, p.isPictureInPicturePossible {
                p.startPictureInPicture()
            } else {
                self.showPiPUnavailableAlert()
            }
        }
    }

    @objc private func tapLock() {
        resetControlsHideTimer()
        presenter?.didRequestLockUI()
    }

    @objc private func tapRotate() {
        resetControlsHideTimer()
        guard let windowScene = view.window?.windowScene else { return }
        let current = windowScene.interfaceOrientation
        let isPortrait = current == .portrait || current == .portraitUpsideDown
        let targetMask: UIInterfaceOrientationMask = isPortrait ? .landscape : .portrait
        playerLockedOrientationMask = targetMask
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        if #available(iOS 16.0, *) {
            let geometry = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: targetMask)
            windowScene.requestGeometryUpdate(geometry) { _ in }
        } else {
            let target: UIDeviceOrientation = isPortrait ? .landscapeRight : .portrait
            UIDevice.current.setValue(target.rawValue, forKey: "orientation")
        }
    }

    @objc private func tapSubtitles() {
        resetControlsHideTimer()
        guard !isAudioMode else { return }

        if PlayerService.shared.isVideoPlayedWithVLC {
            let names = PlayerService.shared.vlcSubtitleTrackNames()
            let currentIdx = PlayerService.shared.vlcCurrentSubtitleIndex()
            let sheet = UIAlertController(title: AppStrings.subtitleTrack, message: nil, preferredStyle: .actionSheet)
            for (idx, name) in names.enumerated() {
                let title = name.isEmpty ? "\(AppStrings.trackOption) \(idx + 1)" : name
                let isSelected = (idx == currentIdx)
                sheet.addAction(UIAlertAction(title: isSelected ? "\(title) ✓" : title, style: .default) { [weak self] _ in
                    PlayerService.shared.vlcSetSubtitleIndex(idx)
                    self?.subtitlesOn = (idx > 0)
                    self?.updateSubtitlesButtonImage()
                })
            }
            if names.isEmpty {
                sheet.addAction(UIAlertAction(title: AppStrings.noSubtitleTracks, style: .default))
            }
            sheet.addAction(UIAlertAction(title: AppStrings.cancel, style: .cancel))
            if let pop = sheet.popoverPresentationController {
                pop.sourceView = subtitlesButton
                pop.sourceRect = subtitlesButton.bounds
            }
            present(sheet, animated: true)
            return
        }

        guard let item = PlayerService.shared.currentPlayer?.currentItem else { return }
        let asset = item.asset
        asset.loadValuesAsynchronously(forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"]) { [weak self, weak item] in
            DispatchQueue.main.async {
                guard let self = self, let item = item else { return }
                let group = asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
                let options = group?.options ?? []
                let current = group.flatMap { item.currentMediaSelection.selectedMediaOption(in: $0) }
                let sheet = UIAlertController(title: AppStrings.subtitleTrack, message: nil, preferredStyle: .actionSheet)
                sheet.addAction(UIAlertAction(title: AppStrings.off, style: .default) { [weak self] _ in
                    if let g = group { item.select(nil, in: g) }
                    self?.subtitlesOn = false
                    self?.updateSubtitlesButtonImage()
                })
                for (idx, option) in options.enumerated() {
                    let title = option.displayName.isEmpty ? "\(AppStrings.trackOption) \(idx + 1)" : option.displayName
                    let isSelected = current.map { $0 === option } ?? false
                    sheet.addAction(UIAlertAction(title: isSelected ? "\(title) ✓" : title, style: .default) { [weak self] _ in
                        if let g = group { item.select(option, in: g) }
                        self?.subtitlesOn = true
                        self?.updateSubtitlesButtonImage()
                    })
                }
                sheet.addAction(UIAlertAction(title: AppStrings.cancel, style: .cancel))
                if let pop = sheet.popoverPresentationController {
                    pop.sourceView = self.subtitlesButton
                    pop.sourceRect = self.subtitlesButton.bounds
                }
                self.present(sheet, animated: true)
            }
        }
    }

    @objc private func tapAudioTrack() {
        resetControlsHideTimer()
        guard !isAudioMode else { return }

        if PlayerService.shared.isVideoPlayedWithVLC {
            let names = PlayerService.shared.vlcAudioTrackNames()
            let currentIdx = PlayerService.shared.vlcCurrentAudioTrackIndex()
            let sheet = UIAlertController(title: AppStrings.audioTrack, message: nil, preferredStyle: .actionSheet)
            for (idx, name) in names.enumerated() {
                let title = name.isEmpty ? "\(AppStrings.trackOption) \(idx + 1)" : name
                let isSelected = (idx == currentIdx)
                sheet.addAction(UIAlertAction(title: isSelected ? "\(title) ✓" : title, style: .default) { _ in
                    PlayerService.shared.vlcSetAudioTrackIndex(idx)
                })
            }
            if names.isEmpty {
                sheet.addAction(UIAlertAction(title: AppStrings.noAlternateAudio, style: .default))
            }
            sheet.addAction(UIAlertAction(title: AppStrings.cancel, style: .cancel))
            if let pop = sheet.popoverPresentationController {
                pop.sourceView = audioTrackButton
                pop.sourceRect = audioTrackButton.bounds
            }
            present(sheet, animated: true)
            return
        }

        guard let item = PlayerService.shared.currentPlayer?.currentItem else { return }
        let asset = item.asset
        asset.loadValuesAsynchronously(forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"]) { [weak self, weak item] in
            DispatchQueue.main.async {
                guard let self = self, let item = item else { return }
                let group = asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
                let options = group?.options ?? []
                let current = group.flatMap { item.currentMediaSelection.selectedMediaOption(in: $0) }
                let sheet = UIAlertController(title: AppStrings.audioTrack, message: nil, preferredStyle: .actionSheet)
                for (idx, option) in options.enumerated() {
                    let title = option.displayName.isEmpty ? "\(AppStrings.trackOption) \(idx + 1)" : option.displayName
                    let isSelected = current.map { $0 === option } ?? false
                    sheet.addAction(UIAlertAction(title: isSelected ? "\(title) ✓" : title, style: .default) { _ in
                        if let g = group { item.select(option, in: g) }
                    })
                }
                if options.isEmpty {
                    sheet.addAction(UIAlertAction(title: AppStrings.noAlternateAudio, style: .default))
                }
                sheet.addAction(UIAlertAction(title: AppStrings.cancel, style: .cancel))
                if let pop = sheet.popoverPresentationController {
                    pop.sourceView = self.audioTrackButton
                    pop.sourceRect = self.audioTrackButton.bounds
                }
                self.present(sheet, animated: true)
            }
        }
    }

    private func updateSubtitlesButtonImage() {
        let name = subtitlesOn ? "subtitles-on" : "subtitles-off"
        subtitlesButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(named: name)), for: .normal)
    }

    private func syncSubtitlesStateFromItem() {
        guard let item = PlayerService.shared.currentPlayer?.currentItem else { return }
        let asset = item.asset
        if asset.statusOfValue(forKey: "availableMediaCharacteristicsWithMediaSelectionOptions", error: nil) == .loaded {
            let group = asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
            let selected = group.flatMap { item.currentMediaSelection.selectedMediaOption(in: $0) }
            subtitlesOn = selected != nil
            updateSubtitlesButtonImage()
        }
    }

    @objc private func tapOverlayLock() {
        presenter?.didRequestUnlockUI()
    }

    @objc private func overlayTapped() {
        guard isUILocked else { return }
        if isOverlayLockButtonVisible {
            hideOverlayLockButtonAnimated()
        } else {
            showOverlayLockButtonTemporarily()
        }
    }

    private func showOverlayLockButtonTemporarily() {
        overlayLockHideTimer?.invalidate()
        overlayLockButton.isUserInteractionEnabled = true
        isOverlayLockButtonVisible = true
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) { [weak self] in
            self?.overlayLockButton.alpha = 1
        }
        overlayLockHideTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.hideOverlayLockButtonAnimated()
        }
        overlayLockHideTimer?.tolerance = 0.2
    }

    private func hideOverlayLockButtonAnimated() {
        overlayLockHideTimer?.invalidate()
        overlayLockHideTimer = nil
        isOverlayLockButtonVisible = false
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) { [weak self] in
            self?.overlayLockButton.alpha = 0
        } completion: { [weak self] _ in
            self?.overlayLockButton.isUserInteractionEnabled = false
        }
    }

    @objc private func closeTapped() {
        resetControlsHideTimer()
        PlayerService.shared.saveProgress()
        if isAudioMode {
            dismiss(animated: true)
        } else {
            PlayerService.shared.clearPlayback()
            dismiss(animated: true)
        }
    }

    @objc private func castTapped() {
        resetControlsHideTimer()
        let vc = TransmittingDeviceViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    @objc private func volumeButtonTapped() {
        if volumeSliderPanel.isHidden {
            topBarContainer.layoutIfNeeded()
            let rect = volumeButton.convert(volumeButton.bounds, to: controlsContainer)
            let w: CGFloat = 44
            let h: CGFloat = 140
            let x = min(max(rect.midX - w / 2, 8), controlsContainer.bounds.width - w - 8)
            let y = rect.maxY + 4
            volumeSliderPanel.frame = CGRect(x: x, y: y, width: w, height: h)
            volumeSlider.value = PlayerService.shared.volume
            volumeSliderPanel.isHidden = false
            controlsContainer.bringSubviewToFront(volumeSliderPanel)
            controlsHideTimer?.invalidate()
            controlsHideTimer = nil
        } else {
            volumeSliderPanel.isHidden = true
            resetControlsHideTimer()
        }
    }

    @objc private func volumeSliderTouchDown() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = nil
    }

    @objc private func volumeSliderDragged() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = nil
    }

    @objc private func volumeSliderTouchCancelledOrEnded() {
        guard !volumeSliderPanel.isHidden, !isAudioMode, !isUILocked else { return }
        scheduleControlsHide()
    }

    @objc private func volumeSliderChanged() {
        let v = volumeSlider.value
        PlayerService.shared.volume = v
        updateVolumeButtonIcon()
    }

    private func updateVolumeButtonIcon() {
        let pct = Int(PlayerService.shared.volume * 100)
        let name: String
        if pct == 0 {
            name = "volume-mute"
        } else if pct <= 50 {
            name = "volume-low"
        } else {
            name = "volume-high"
        }
            volumeButton.setImage(imageResizedTo24(UIImage(named: name)), for: .normal)
    }

    func showProgress(current: TimeInterval, duration: TimeInterval) {
        let remaining = max(0, duration - current)
        if !isVideoScrubbing && !isPanSeekInProgress {
            currentTimeLabel.text = formatTime(current)
            remainingTimeLabel.text = "-" + formatTime(remaining)
        }
        if !progressSlider.isHighlighted && !isVideoScrubbing && !isPanSeekInProgress && duration > 0 {
            progressSlider.value = Float(current / duration)
        }
        if !isAudioScrubbing {
            audioCurrentTimeLabel.text = formatTime(current)
            audioRemainingTimeLabel.text = "-" + formatTime(remaining)
        }
        if !audioProgressSlider.isHighlighted && !isAudioScrubbing && duration > 0 {
            audioProgressSlider.value = Float(current / duration)
        }
    }

    func showPlaybackState(isPlaying: Bool) {
        let name = isPlaying ? "pause" : "play"
        playPauseButton.setImage(imageResizedTo(CGSize(width: 69, height: 69), UIImage(named: name)), for: .normal)
        let audioName = isPlaying ? "audio-pause" : "audio-play"
        let img = (UIImage(named: audioName) ?? UIImage(named: name))?.withRenderingMode(.alwaysOriginal)
        audioPlayPauseButton.setImage(imageResizedTo(CGSize(width: 70, height: 70), img), for: .normal)
    }

    func showItem(title: String, author: String?, coverImageURL: URL?) {
        titleLabel.text = title
        audioTitleLabel.text = title
        audioSubtitleLabel.text = author ?? ""
        albumArtImageView.image = coverImageURL.flatMap { UIImage(contentsOfFile: $0.path) }.flatMap { imageScaledToAlbumArtSize($0) } ?? DefaultCover.audioBackground
        DispatchQueue.main.async { [weak self] in
            self?.startMarqueeIfNeeded()
        }
        if !isAudioMode {
            let useVLC = PlayerService.shared.isVideoPlayedWithVLC
            PlayerService.shared.setVideoDrawable(useVLC ? vlcVideoView : nil)
            playerLayer?.player = useVLC ? nil : PlayerService.shared.currentPlayer
            playerLayer?.frame = view.bounds
            if !useVLC {
                setupPiPIfNeeded()
            } else {
                pipController = nil
            }
        }
        updateLayoutForMode()
        if !isAudioMode {
            if PlayerService.shared.isVideoPlayedWithVLC {
                subtitlesOn = PlayerService.shared.vlcCurrentSubtitleIndex() > 0
                updateSubtitlesButtonImage()
            } else if let item = PlayerService.shared.currentPlayer?.currentItem {
                item.asset.loadValuesAsynchronously(forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"]) { [weak self] in
                    DispatchQueue.main.async { self?.syncSubtitlesStateFromItem() }
                }
            }
        }
    }

    func showSpeed(_ speed: PlaybackSpeed) {
        let name: String
        switch speed {
        case .half: name = "speed-0.5x"
        case .normal: name = "speed-1.0x"
        case .oneQuarter: name = "speed-1.25x"
        case .oneHalf: name = "speed-1.5x"
        case .double: name = "speed-2.0x"
        }
        speedButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(named: name)), for: .normal)
    }

    func showPlaybackMode(_ mode: PlaybackMode) {
        if isAudioMode {
            let shuffleHighlight = (mode == .shuffle)
            audioShuffleButton.tintColor = shuffleHighlight ? .systemPurple : .white
            updateAudioRepeatButtonImage(mode: mode)
        } else {
            playNextOn = (mode != .stopAfterCurrent)
            updatePlayNextButtonImage()
            let shuffleHighlight = (mode == .shuffle)
            shuffleButton.tintColor = shuffleHighlight ? .systemPurple : .white
        }
    }

    private func updateLayoutForMode() {
        let audio = isAudioMode
        if audio {
            backgroundImageView.image = UIImage(named: "load_back")
            backgroundImageView.contentMode = .scaleAspectFill
            backgroundImageView.backgroundColor = .clear
            view.backgroundColor = .clear
            view.sendSubviewToBack(backgroundImageView)
            topBarTopToSafeArea?.isActive = false
            topBarTopToView?.isActive = true
            topBarHeightConstraint?.constant = 44 + view.safeAreaInsets.top
            topBarContainer.backgroundColor = .clear
            topBarContainer.isOpaque = false
        } else {
            backgroundImageView.image = nil
            backgroundImageView.backgroundColor = .black
            view.backgroundColor = .black
            topBarTopToView?.isActive = false
            topBarTopToSafeArea?.isActive = true
            topBarHeightConstraint?.constant = 44
            topBarContainer.backgroundColor = UIColor.black.withAlphaComponent(0.85)
            topBarContainer.isOpaque = false
        }
        audioContainerView?.isHidden = !audio
        centerControlsContainer?.isHidden = audio
        bottomControlsContainer?.isHidden = audio
        volumeButton.isHidden = audio
        subtitlesButton.isHidden = audio
        audioTrackButton.isHidden = audio
        pipButton.isHidden = audio
        vlcVideoView.isHidden = audio || !PlayerService.shared.isVideoPlayedWithVLC
        if traitCollection.userInterfaceIdiom == .pad {
            let inset: CGFloat = audio ? 74 : 12
            backButtonLeadingConstraint?.constant = inset
            castButtonTrailingConstraint?.constant = -inset
            view.setNeedsLayout()
        } else {
            let inset: CGFloat = audio ? 24 : 12
            backButtonLeadingConstraint?.constant = inset
            castButtonTrailingConstraint?.constant = -inset
            view.setNeedsLayout()
        }
    }

    func showError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppStrings.ok, style: .default))
        present(alert, animated: true)
    }

    func showUILocked(_ locked: Bool) {
        isUILocked = locked
        unlockOverlay.isHidden = !locked
        controlsContainer.isHidden = locked
        lockButton.setImage(imageResizedTo(CGSize(width: 25, height: 25), UIImage(named: "unlock")), for: .normal)
        if locked {
            volumeSliderPanel.isHidden = true
            controlsHideTimer?.invalidate()
            controlsHideTimer = nil
            showOverlayLockButtonTemporarily()
        } else {
            overlayLockHideTimer?.invalidate()
            overlayLockHideTimer = nil
            isOverlayLockButtonVisible = false
            overlayLockButton.alpha = 0
            overlayLockButton.isUserInteractionEnabled = false
            controlsVisible = true
            controlsContainer.alpha = 1
            controlsContainer.isUserInteractionEnabled = true
            scheduleControlsHide()
        }
    }

    private func imageResizedTo24(_ image: UIImage?) -> UIImage? {
        imageResizedTo(CGSize(width: 24, height: 24), image)
    }

    private func imageResizedTo(_ size: CGSize, _ image: UIImage?) -> UIImage? {
        guard let image = image else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        .withRenderingMode(image.renderingMode)
    }

    private static let albumArtMaxSize: CGFloat = 290

    private func imageScaledToAlbumArtSize(_ image: UIImage?) -> UIImage? {
        guard let image = image else { return nil }
        let w = image.size.width
        let h = image.size.height
        guard w > 0, h > 0 else { return image }
        let maxS = Self.albumArtMaxSize
        if w <= maxS && h <= maxS { return image }
        let scale = min(maxS / w, maxS / h)
        let newSize = CGSize(width: w * scale, height: h * scale)
        return imageResizedTo(newSize, image)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let safe = t.isFinite ? max(0, t) : 0
        let m = Int(safe) / 60
        let s = Int(safe) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startMarqueeIfNeeded() {
        marqueeAnimation?.stopAnimation(true)
        marqueeAnimation = nil
        titleLabel.layer.removeAllAnimations()
        titleLabel.transform = .identity
        guard titleMarqueeContainer.bounds.width > 0 else { return }
        titleLabel.sizeToFit()
        let labelW = titleLabel.bounds.width
        let containerW = titleMarqueeContainer.bounds.width
        guard labelW > containerW else { return }
        let halfExtra = (labelW - containerW) / 2
        let duration = TimeInterval((labelW - containerW) / 30)
        titleLabel.transform = CGAffineTransform(translationX: halfExtra, y: 0)
        marqueeAnimation = UIViewPropertyAnimator(duration: duration, curve: .linear) { [weak self] in
            self?.titleLabel.transform = CGAffineTransform(translationX: -halfExtra, y: 0)
        }
        marqueeAnimation?.addCompletion { [weak self] _ in
            self?.titleLabel.transform = .identity
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.startMarqueeIfNeeded()
            }
        }
        marqueeAnimation?.startAnimation(afterDelay: 1)
    }
}
