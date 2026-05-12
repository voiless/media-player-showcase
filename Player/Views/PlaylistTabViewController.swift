import UIKit

final class PlaylistTabViewController: UIViewController, TabContentControlling {

    var onPlusTapped: (() -> Void)?

    private let purpleAccent = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1.0)

    private let backgroundImageView: UIImageView = {
        let v = UIImageView()
        v.image = UIImage(named: "load_back")
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFonts.bold(22)
        l.textColor = .white
        l.fitTextWithinBounds(multiline: true)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.showsVerticalScrollIndicator = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let gridStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 20
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private var playlists: [Playlist] = []
    private var gridRows: [UIStackView] = []
    private static let rowSpacing: CGFloat = 16
    private static let cardWidth: CGFloat = 158
    private static let horizontalInset: CGFloat = 20
    private var gridStackWidthConstraint: NSLayoutConstraint?
    private var lastLayoutWidth: CGFloat = 0

    private func availableWidthForGrid() -> CGFloat {
        let w = scrollView.bounds.width > 0 ? scrollView.bounds.width : view.bounds.width
        return max(0, w - Self.horizontalInset * 2)
    }

    private func numberOfColumns() -> Int {
        let availableWidth = availableWidthForGrid()
        guard availableWidth > 0 else { return 2 }
        let n = Int((availableWidth + Self.rowSpacing) / (Self.cardWidth + Self.rowSpacing))
        return max(1, n)
    }

    private func rowWidthForColumns(_ cols: Int) -> CGFloat {
        CGFloat(cols) * Self.cardWidth + CGFloat(max(0, cols - 1)) * Self.rowSpacing
    }
    private static let cardHeight: CGFloat = 135
    private static let cardCornerRadius: CGFloat = 5
    private static let cardBarColor = UIColor(red: 0x18/255, green: 0x0C/255, blue: 0x28/255, alpha: 1)
    private static let cardBarColorTemplate = UIColor(red: 0x18/255, green: 0x0C/255, blue: 0x28/255, alpha: 0.65)

    override func loadView() {
        view = UIView()
        view.backgroundColor = .black
    }

    private let contentWrapper: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(backgroundImageView)
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(contentWrapper)
        contentWrapper.addSubview(gridStack)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentWrapper.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentWrapper.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentWrapper.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentWrapper.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentWrapper.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            gridStack.topAnchor.constraint(equalTo: contentWrapper.topAnchor),
            gridStack.centerXAnchor.constraint(equalTo: contentWrapper.centerXAnchor),
            gridStack.bottomAnchor.constraint(equalTo: contentWrapper.bottomAnchor)
        ])
        titleLabel.text = AppStrings.playlist
        reloadGrid()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = scrollView.bounds.width
        if w > 0, w != lastLayoutWidth {
            lastLayoutWidth = w
            reloadGrid()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        playlists = MediaStorageService.shared.loadPlaylists()
        reloadGrid()
    }

    private func reloadGrid() {
        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        gridRows.removeAll()

        let cols = numberOfColumns()
        gridStackWidthConstraint?.isActive = false
        gridStackWidthConstraint = gridStack.widthAnchor.constraint(equalToConstant: rowWidthForColumns(cols))
        gridStackWidthConstraint?.isActive = true

        let newAlbumCard = makeNewPlaylistCard()
        newAlbumCard.isUserInteractionEnabled = true
        let tapNew = UITapGestureRecognizer(target: self, action: #selector(newPlaylistTapped))
        newAlbumCard.addGestureRecognizer(tapNew)

        var rowStack: UIStackView?
        var rowCount = 0
        rowStack = makeRowStack()
        gridStack.addArrangedSubview(rowStack!)
        rowStack!.addArrangedSubview(newAlbumCard)
        newAlbumCard.widthAnchor.constraint(equalToConstant: Self.cardWidth).isActive = true
        newAlbumCard.setContentHuggingPriority(.required, for: .horizontal)
        rowCount = 1
        if playlists.isEmpty {
            while rowCount < numberOfColumns() {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                rowStack!.addArrangedSubview(spacer)
                rowCount += 1
            }
        }

        for (idx, playlist) in playlists.enumerated() {
            if rowCount == numberOfColumns() {
                rowStack = makeRowStack()
                gridStack.addArrangedSubview(rowStack!)
                rowCount = 0
            }
            let card = makePlaylistCard(playlist: playlist, index: idx)
            rowStack!.addArrangedSubview(card)
            card.widthAnchor.constraint(equalToConstant: Self.cardWidth).isActive = true
            card.setContentHuggingPriority(.required, for: .horizontal)
            rowCount += 1
        }
        if rowCount > 0 {
            while rowCount < numberOfColumns() {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                rowStack!.addArrangedSubview(spacer)
                rowCount += 1
            }
        }
    }

    private func makeRowStack() -> UIStackView {
        let s = UIStackView()
        s.axis = .horizontal
        s.distribution = .fill
        s.spacing = Self.rowSpacing
        s.alignment = .top
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }

    private func makeNewPlaylistCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = Self.cardCornerRadius
        card.clipsToBounds = true

        let coverImageView = UIImageView(image: DefaultCover.albumCreateCover155x135)
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.layer.cornerRadius = Self.cardCornerRadius
        coverImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(coverImageView)

        let buttonLight = UIImageView(image: UIImage(named: "button_light")?.withRenderingMode(.alwaysOriginal))
        buttonLight.contentMode = .scaleAspectFit
        buttonLight.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(buttonLight)

        let barView = UIView()
        barView.backgroundColor = Self.cardBarColorTemplate
        barView.layer.cornerRadius = Self.cardCornerRadius
        barView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        barView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(barView)

        let titleLabel = UILabel()
        titleLabel.text = AppStrings.newPlaylistLowercase
        titleLabel.font = AppFonts.semibold(14)
        titleLabel.textColor = .white
        titleLabel.fitTextWithinBounds(multiline: true)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        barView.addSubview(titleLabel)

        let barH: CGFloat = 38
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Self.cardWidth),
            card.heightAnchor.constraint(equalToConstant: Self.cardHeight),
            coverImageView.topAnchor.constraint(equalTo: card.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalToConstant: Self.cardHeight - barH),
            buttonLight.centerXAnchor.constraint(equalTo: coverImageView.centerXAnchor),
            buttonLight.centerYAnchor.constraint(equalTo: coverImageView.centerYAnchor),
            buttonLight.widthAnchor.constraint(equalToConstant: 34),
            buttonLight.heightAnchor.constraint(equalToConstant: 34),
            barView.topAnchor.constraint(equalTo: coverImageView.bottomAnchor),
            barView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            barView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            barView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: barView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: barView.centerYAnchor)
        ])
        return card
    }

    private func makePlaylistCard(playlist: Playlist, index: Int) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = Self.cardCornerRadius
        card.clipsToBounds = true

        let coverImageView = UIImageView(image: DefaultCover.playlistFolderCover155x135)
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.layer.cornerRadius = Self.cardCornerRadius
        coverImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(coverImageView)

        let bar = UIView()
        bar.backgroundColor = Self.cardBarColor
        bar.layer.cornerRadius = Self.cardCornerRadius
        bar.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        bar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bar)

        let titleLabel = UILabel()
        titleLabel.text = playlist.name
        titleLabel.font = AppFonts.semibold(14)
        titleLabel.textColor = .white
        titleLabel.fitTextWithinBounds(multiline: true)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        let count = playlist.itemIds.count
        let trackLabel = UILabel()
        trackLabel.text = playlist.kind == .video ? AppStrings.videoLabel(count: count) : AppStrings.trackLabel(count: count)
        trackLabel.font = AppFonts.regular(11)
        trackLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        trackLabel.fitTextWithinBounds(multiline: false)
        trackLabel.translatesAutoresizingMaskIntoConstraints = false
        trackLabel.numberOfLines = 1
        trackLabel.lineBreakMode = .byTruncatingTail
        let menuButton = TouchTargetButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        menuButton.setImage(UIImage(systemName: "ellipsis", withConfiguration: config), for: .normal)
        menuButton.tintColor = .white
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.tag = index
        menuButton.addTarget(self, action: #selector(playlistMenuTapped(_:)), for: .touchUpInside)
        bar.addSubview(titleLabel)
        bar.addSubview(trackLabel)
        bar.addSubview(menuButton)
        card.addSubview(bar)
        let barH: CGFloat = 38
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Self.cardWidth),
            card.heightAnchor.constraint(equalToConstant: Self.cardHeight),
            coverImageView.topAnchor.constraint(equalTo: card.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalToConstant: Self.cardHeight - barH),
            bar.topAnchor.constraint(equalTo: coverImageView.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: bar.topAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: menuButton.leadingAnchor, constant: -8),
            trackLabel.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            trackLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            trackLabel.trailingAnchor.constraint(lessThanOrEqualTo: menuButton.leadingAnchor, constant: -8),
            trackLabel.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -4),
            menuButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            menuButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        card.accessibilityIdentifier = playlist.id
        let tapCard = UITapGestureRecognizer(target: self, action: #selector(playlistCardTapped(_:)))
        card.addGestureRecognizer(tapCard)
        card.isUserInteractionEnabled = true
        return card
    }

    @objc private func newPlaylistTapped() {
        showNewPlaylistDialog()
    }

    @objc private func playlistCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let card = gesture.view, let id = card.accessibilityIdentifier else { return }
        guard let playlist = playlists.first(where: { $0.id == id }) else { return }
        let listVC = PlaylistDetailViewController(playlist: playlist)
        listVC.delegate = self
        let nav = UINavigationController(rootViewController: listVC)
        nav.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        }
        present(nav, animated: true)
    }

    @objc private func playlistMenuTapped(_ sender: UIButton) {
        let idx = sender.tag
        guard idx >= 0 && idx < playlists.count else { return }
        let playlist = playlists[idx]
        showPlaylistOptionsSheet(playlist: playlist)
    }

    private func showPlaylistOptionsSheet(playlist: Playlist) {
        let sheet = DarkActionSheetViewController()
        sheet.titleText = AppStrings.selectionOfChanges
        sheet.actions = [
            (AppStrings.rename, .default, { [weak self] in self?.showRenameDialog(playlist: playlist) }),
            (AppStrings.delete, .destructive, { [weak self] in self?.showDeleteConfirm(playlist: playlist) })
        ]
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle = .crossDissolve
        present(sheet, animated: true)
    }

    func showNewPlaylistDialog() {
        let sheet = DarkActionSheetViewController()
        sheet.titleText = AppStrings.newPlaylist
        sheet.actions = [
            (AppStrings.videoPlaylist, .default, { [weak self] in self?.showNewPlaylistNameDialog(kind: .video) }),
            (AppStrings.audioPlaylist, .default, { [weak self] in self?.showNewPlaylistNameDialog(kind: .audio) }),
            (AppStrings.cancel, .default, nil)
        ]
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle = .crossDissolve
        present(sheet, animated: true)
    }

    private func showNewPlaylistNameDialog(kind: MediaItemKind) {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.newPlaylist
        vc.messageText = AppStrings.chooseTitleForNewPlaylist
        vc.placeholder = AppStrings.placeholder
        vc.onSave = { [weak self] name in self?.createPlaylist(name: name, kind: kind) }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func showRenameDialog(playlist: Playlist) {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.rename
        vc.initialText = playlist.name
        vc.onSave = { [weak self] name in self?.renamePlaylist(playlist, name: name) }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func showDeleteConfirm(playlist: Playlist) {
        let vc = DarkConfirmViewController()
        vc.titleText = AppStrings.areYouSure
        vc.messageText = AppStrings.confirmFileDeletion
        vc.onDelete = { [weak self] in self?.deletePlaylist(playlist) }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func createPlaylist(name: String, kind: MediaItemKind = .video) {
        var list = MediaStorageService.shared.loadPlaylists()
        let newPlaylist = Playlist(id: UUID().uuidString, name: name, itemIds: [], createdAt: Date(), kind: kind)
        list.append(newPlaylist)
        MediaStorageService.shared.savePlaylists(list)
        playlists = list
        reloadGrid()
    }

    private func renamePlaylist(_ playlist: Playlist, name: String) {
        var list = MediaStorageService.shared.loadPlaylists()
        guard let idx = list.firstIndex(where: { $0.id == playlist.id }) else { return }
        list[idx].name = name
        MediaStorageService.shared.savePlaylists(list)
        playlists = list
        reloadGrid()
    }

    private func deletePlaylist(_ playlist: Playlist) {
        var list = MediaStorageService.shared.loadPlaylists()
        list.removeAll { $0.id == playlist.id }
        MediaStorageService.shared.savePlaylists(list)
        playlists = list
        reloadGrid()
    }
}

extension PlaylistTabViewController: PlaylistDetailViewControllerDelegate {
    func playlistDetailDidUpdate() {
        playlists = MediaStorageService.shared.loadPlaylists()
        reloadGrid()
    }
}
