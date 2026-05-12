import UIKit
import UniformTypeIdentifiers

final class MenuViewController: UIViewController {

    private let purpleAccent = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1.0)

    private let backgroundImageView: UIImageView = {
        let v = UIImageView()
        v.image = UIImage(named: "load_back")
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let contentContainerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private static let tabBarHeight: CGFloat = 93

    private let tabBarContainer: UIView = {
        let v = UIView()
        v.backgroundColor = AppColors.bottomPanel
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let tabStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.distribution = .fillEqually
        s.alignment = .fill
        s.spacing = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let plusButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.setImage(UIImage(named: "button_dark")?.withRenderingMode(.alwaysOriginal), for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private var selectedTabIndex = 0
    private var tabCells: [UIView] = []
    private let videoTabVC = VideoTabViewController()
    private let audioTabVC = AudioTabViewController()
    private let playlistTabVC = PlaylistTabViewController()
    private let settingsTabVC = SettingsViewController()
    private var currentChild: UIViewController?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override var shouldAutorotate: Bool { false }

    override func loadView() {
        let v = UIView()
        v.backgroundColor = .black
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.addSubview(backgroundImageView)
        view.addSubview(contentContainerView)
        view.addSubview(tabBarContainer)
        tabBarContainer.addSubview(tabStack)
        tabBarContainer.addSubview(plusButton)
        tabStack.isUserInteractionEnabled = true
        tabBarContainer.bringSubviewToFront(plusButton)

        videoTabVC.onPlusTapped = { [weak self] in self?.openAddVideo() }
        videoTabVC.onPlayVideo = { [weak self] items, idx in self?.playVideoWithItems(items, startIndex: idx) }
        audioTabVC.onPlusTapped = { [weak self] in self?.openAddAudio() }
        audioTabVC.onPlayAudio = { [weak self] items, idx in self?.playAudioWithItems(items, startIndex: idx) }
        playlistTabVC.onPlusTapped = { [weak playlistTabVC] in playlistTabVC?.showNewPlaylistDialog() }
        settingsTabVC.onPlusTapped = nil

        let tabItems: [(String, String, String)] = [
            (AppStrings.video, "video_on", "video_off"),
            (AppStrings.audio, "music_on", "music_off"),
            ("", "", ""),
            (AppStrings.myPlaylist, "playlist_on", "playlist_off"),
            (AppStrings.settings, "settings_on", "settings_off")
        ]
        for (idx, item) in tabItems.enumerated() {
            if item.0.isEmpty {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.isUserInteractionEnabled = false
                tabStack.addArrangedSubview(spacer)
                continue
            }
            let tabCell = makeTabCell(title: item.0, imageOn: item.1, imageOff: item.2, isSelected: idx == 0)
            tabCell.tag = idx
            tabCells.append(tabCell)
            let tap = UITapGestureRecognizer(target: self, action: #selector(tabTapped(_:)))
            tabCell.addGestureRecognizer(tap)
            tabStack.addArrangedSubview(tabCell)
        }

        plusButton.addTarget(self, action: #selector(plusTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabBarContainer.heightAnchor.constraint(equalToConstant: Self.tabBarHeight),
            tabStack.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            tabStack.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor),
            tabStack.topAnchor.constraint(equalTo: tabBarContainer.topAnchor, constant: 10),
            tabStack.bottomAnchor.constraint(equalTo: tabBarContainer.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            plusButton.centerXAnchor.constraint(equalTo: tabBarContainer.centerXAnchor),
            plusButton.centerYAnchor.constraint(equalTo: tabBarContainer.topAnchor, constant: 28),
            plusButton.widthAnchor.constraint(equalToConstant: 60),
            plusButton.heightAnchor.constraint(equalToConstant: 60)
        ])

        switchToTab(0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func switchToTab(_ index: Int) {
        if index == 2 {
            (currentChild as? TabContentControlling)?.onPlusTapped?()
            return
        }
        selectedTabIndex = index
        for cell in tabCells {
            updateTabCell(cell, isSelected: cell.tag == selectedTabIndex)
        }
        let child: UIViewController
        switch index {
        case 0: child = videoTabVC
        case 1: child = audioTabVC
        case 3: child = playlistTabVC
        case 4: child = settingsTabVC
        default: return
        }
        currentChild?.willMove(toParent: nil)
        currentChild?.view.removeFromSuperview()
        currentChild?.removeFromParent()
        addChild(child)
        contentContainerView.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            child.view.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor)
        ])
        child.didMove(toParent: self)
        currentChild = child
    }

    private static let tabImageNames: [(on: String, off: String)] = [
        ("video_on", "video_off"),
        ("music_on", "music_off"),
        ("", ""),
        ("playlist_on", "playlist_off"),
        ("settings_on", "settings_off")
    ]

    private func updateTabCell(_ cell: UIView, isSelected: Bool) {
        let iconView = cell.subviews.first { $0 is UIImageView } as? UIImageView
        let label = cell.subviews.compactMap { $0 as? UILabel }.first
        let idx = cell.tag
        if idx >= 0, idx < Self.tabImageNames.count, !Self.tabImageNames[idx].on.isEmpty,
           let img = UIImage(named: isSelected ? Self.tabImageNames[idx].on : Self.tabImageNames[idx].off) {
            iconView?.image = img.withRenderingMode(.alwaysOriginal)
        }
        let inactiveColor = UIColor(white: 0.65, alpha: 1)
        label?.font = isSelected ? AppFonts.bold(10) : AppFonts.regular(10)
        label?.textColor = isSelected ? purpleAccent : inactiveColor
    }

    private func makeTabCell(title: String, imageOn: String, imageOff: String, isSelected: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = true
        let imgName = isSelected ? imageOn : imageOff
        let img = UIImage(named: imgName)?.withRenderingMode(.alwaysOriginal)
        let iconView = UIImageView(image: img)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = title
        label.font = isSelected ? AppFonts.bold(10) : AppFonts.regular(10)
        label.textColor = isSelected ? purpleAccent : UIColor(white: 0.65, alpha: 1)
        label.textAlignment = .center
        label.fitTextWithinBounds(multiline: false)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: container.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.heightAnchor.constraint(equalToConstant: 26),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            label.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
        ])
        return container
    }

    @objc private func tabTapped(_ gesture: UITapGestureRecognizer) {
        guard let cell = gesture.view else { return }
        switchToTab(cell.tag)
    }

    @objc private func plusTapped() {
        switchToTab(2)
    }

    private func openAddVideo() {
        MediaImportService.shared.presentAddSource(from: self, kind: .video)
    }

    private func openAddAudio() {
        MediaImportService.shared.presentAddSource(from: self, kind: .audio)
    }

    private func playVideoWithItems(_ items: [MediaItem], startIndex: Int) {
        let playerVC = PlayerViewController()
        let presenter = PlayerPresenter(view: playerVC, playerService: PlayerService.shared)
        playerVC.presenter = presenter
        playerVC.setQueue(items, startIndex: startIndex)
        let nav = PlayerNavigationController(rootViewController: playerVC)
        nav.modalPresentationStyle = .fullScreen
        presentPlayerFromTopmost(nav)
    }

    private func playAudioWithItems(_ items: [MediaItem], startIndex: Int) {
        playVideoWithItems(items, startIndex: startIndex)
    }

    private func presentPlayerFromTopmost(_ nav: UINavigationController) {
        func doPresent(from vc: UIViewController?) {
            guard let vc = vc else { return }
            vc.present(nav, animated: true)
        }
        if view.window != nil {
            DispatchQueue.main.async { [weak self] in doPresent(from: self) }
        } else {
            let top = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
                .flatMap { w -> UIViewController? in
                    var vc = w.rootViewController
                    while let p = vc?.presentedViewController { vc = p }
                    return vc
                }
            DispatchQueue.main.async { doPresent(from: top) }
        }
    }
}
