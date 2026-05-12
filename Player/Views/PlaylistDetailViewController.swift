import UIKit

protocol PlaylistDetailViewControllerDelegate: AnyObject {
    func playlistDetailDidUpdate()
}

final class PlaylistDetailViewController: UIViewController {

    weak var delegate: PlaylistDetailViewControllerDelegate?

    private let playlist: Playlist
    private var items: [String] = []

    private let backgroundImageView: UIImageView = {
        let v = UIImageView()
        v.image = UIImage(named: "load_back")
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.backgroundColor = .clear
        t.separatorStyle = .none
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    init(playlist: Playlist) {
        self.playlist = playlist
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(backgroundImageView)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem.touchTargetBackChevron(target: self, action: #selector(backTapped))
        navigationItem.leftBarButtonItem?.tintColor = .white
        navigationItem.title = playlist.name
        let addBtn = UIBarButtonItem.touchTargetAdd(target: self, action: #selector(addItemsTapped))
        let menuBtn = UIBarButtonItem.touchTargetEllipsis(target: self, action: #selector(playlistMenuTapped))
        (addBtn.customView as? UIButton)?.tintColor = .white
        (menuBtn.customView as? UIButton)?.tintColor = .white
        navigationItem.rightBarButtonItems = [menuBtn, addBtn]
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.barTintColor = .clear
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PlaylistTrackCell.self, forCellReuseIdentifier: PlaylistTrackCell.reuseId)
        items = playlist.itemIds
    }

    @objc private func backTapped() {
        delegate?.playlistDetailDidUpdate()
        dismiss(animated: true)
    }

    @objc private func addItemsTapped() {
        let list = MediaStorageService.shared.loadPlaylists()
        let current = list.first(where: { $0.id == playlist.id })
        let existingIds = Set(current?.itemIds ?? [])
        let available: [MediaItem]
        if playlist.kind == .video {
            available = MediaStorageService.shared.loadVideoItems().filter { !existingIds.contains($0.id) }
        } else {
            available = MediaStorageService.shared.loadAudioItems().filter { !existingIds.contains($0.id) }
        }
        if available.isEmpty {
            let vc = DarkConfirmViewController()
            vc.titleText = nil
            vc.messageText = playlist.kind == .video ? AppStrings.noVideosAvailableToAdd : AppStrings.noAudioTracksAvailableToAdd
            vc.deleteTitle = AppStrings.ok
            vc.onDelete = { [weak vc] in vc?.dismiss(animated: true) }
            vc.singleButtonMode = true
            vc.modalPresentationStyle = .overFullScreen
            vc.modalTransitionStyle = .crossDissolve
            present(vc, animated: true)
            return
        }
        let picker = PlaylistItemPickerViewController(items: available, playlistKind: playlist.kind) { [weak self] selectedItems in
            self?.dismiss(animated: true)
            self?.addItemsToPlaylist(selectedItems)
        }
        let nav = UINavigationController(rootViewController: picker)
        nav.modalPresentationStyle = .fullScreen
        nav.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.navigationBar.barTintColor = .black
        nav.navigationBar.isTranslucent = true
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            nav.navigationBar.standardAppearance = appearance
            nav.navigationBar.scrollEdgeAppearance = appearance
            nav.navigationBar.compactAppearance = appearance
        }
        present(nav, animated: true)
    }

    private func addItemToPlaylist(_ item: MediaItem) {
        addItemsToPlaylist([item])
    }

    private func addItemsToPlaylist(_ selectedItems: [MediaItem]) {
        guard !selectedItems.isEmpty else { return }
        var list = MediaStorageService.shared.loadPlaylists()
        guard let idx = list.firstIndex(where: { $0.id == playlist.id }) else { return }
        let existingSet = Set(list[idx].itemIds)
        for item in selectedItems where !existingSet.contains(item.id) {
            list[idx].itemIds.append(item.id)
        }
        MediaStorageService.shared.savePlaylists(list)
        items = list[idx].itemIds
        tableView.reloadData()
    }

    @objc private func playlistMenuTapped() {
        let sheet = DarkActionSheetViewController()
        sheet.titleText = AppStrings.selectionOfChanges
        sheet.actions = [
            (AppStrings.rename, .default, { [weak self] in self?.showRenamePlaylistDialog() }),
            (AppStrings.delete, .destructive, { [weak self] in self?.showDeletePlaylistConfirm() })
        ]
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle = .crossDissolve
        present(sheet, animated: true)
    }

    private func showRenamePlaylistDialog() {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.rename
        vc.initialText = playlist.name
        vc.onSave = { [weak self] name in
            guard let self = self else { return }
            var list = MediaStorageService.shared.loadPlaylists()
            guard let idx = list.firstIndex(where: { $0.id == self.playlist.id }) else { return }
            list[idx].name = name
            MediaStorageService.shared.savePlaylists(list)
            self.navigationItem.title = name
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func showDeletePlaylistConfirm() {
        let vc = DarkConfirmViewController()
        vc.titleText = AppStrings.areYouSure
        vc.messageText = AppStrings.confirmFileDeletion
        vc.onDelete = { [weak self] in
            guard let self = self else { return }
            var list = MediaStorageService.shared.loadPlaylists()
            list.removeAll { $0.id == self.playlist.id }
            MediaStorageService.shared.savePlaylists(list)
            self.delegate?.playlistDetailDidUpdate()
            self.dismiss(animated: true)
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }
}

extension PlaylistDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PlaylistTrackCell.reuseId, for: indexPath) as! PlaylistTrackCell
        let itemId = items[indexPath.row]
        let resolved = MediaStorageService.shared.mediaItem(byId: itemId)
        cell.showMenuButton = true
        cell.configure(
            title: resolved?.title ?? AppStrings.unknown,
            subtitle: resolved?.author ?? "",
            coverImageURL: resolved?.coverImageURL
        )
        cell.onMenuTapped = { [weak self] in
            self?.showTrackOptionsSheet(indexPath: indexPath)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let itemId = items[indexPath.row]
        guard let item = MediaStorageService.shared.mediaItem(byId: itemId) else { return }
        let inPlaylist = items.compactMap { MediaStorageService.shared.mediaItem(byId: $0) }
        guard let idx = inPlaylist.firstIndex(where: { $0.id == item.id }) else { return }
        let playerVC = PlayerViewController()
        let presenter = PlayerPresenter(view: playerVC, playerService: PlayerService.shared)
        playerVC.presenter = presenter
        playerVC.setQueue(inPlaylist, startIndex: idx)
        let nav = PlayerNavigationController(rootViewController: playerVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func showTrackOptionsSheet(indexPath: IndexPath) {
        let sheetVC = PlaylistTrackSheetViewController()
        sheetVC.onRename = { [weak self] in
            self?.renameTrack(at: indexPath)
        }
        sheetVC.onDelete = { [weak self] in
            self?.deleteTrack(at: indexPath)
        }
        sheetVC.modalPresentationStyle = .pageSheet
        present(sheetVC, animated: true)
    }

    private func renameTrack(at indexPath: IndexPath) {
    }

    private func deleteTrack(at indexPath: IndexPath) {
        var list = MediaStorageService.shared.loadPlaylists()
        guard let idx = list.firstIndex(where: { $0.id == playlist.id }), indexPath.row < list[idx].itemIds.count else { return }
        list[idx].itemIds.remove(at: indexPath.row)
        MediaStorageService.shared.savePlaylists(list)
        items = list[idx].itemIds
        tableView.reloadData()
    }
}

final class PlaylistTrackSheetViewController: UIViewController {
    var onRename: (() -> Void)?
    var onDelete: (() -> Void)?

    private let containerBg = UIColor(red: 0x22/255, green: 0x1C/255, blue: 0x2E/255, alpha: 1)
    private let buttonBg = UIColor(red: 0x2A/255, green: 0x24/255, blue: 0x36/255, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = containerBg
        let titleLabel = UILabel()
        titleLabel.text = AppStrings.selectionOfChanges
        titleLabel.font = AppFonts.regular(14)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        titleLabel.fitTextWithinBounds(multiline: true)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let renameBtn = makeActionButton(icon: "pencil", title: AppStrings.rename)
        renameBtn.addTarget(self, action: #selector(renameTapped), for: .touchUpInside)
        let deleteBtn = makeActionButton(icon: "trash", title: AppStrings.delete)
        deleteBtn.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [renameBtn, deleteBtn])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func makeActionButton(icon: String, title: String) -> UIButton {
        let btn = TouchTargetButton(type: .system)
        btn.backgroundColor = buttonBg
        btn.layer.cornerRadius = AppColors.cardCornerRadius
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.contentHorizontalAlignment = .left
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        btn.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = AppFonts.regular(17)
        btn.fitTitleWithinBounds(maxLines: 2)
        btn.tintColor = .white
        btn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return btn
    }

    @objc private func renameTapped() {
        view.isUserInteractionEnabled = false
        let callback = onRename
        onRename = nil
        onDelete = nil
        dismiss(animated: true) {
            DispatchQueue.main.async { callback?() }
        }
    }

    @objc private func deleteTapped() {
        view.isUserInteractionEnabled = false
        let callback = onDelete
        onRename = nil
        onDelete = nil
        dismiss(animated: true) {
            DispatchQueue.main.async { callback?() }
        }
    }
}

private final class PlaylistTrackCell: UITableViewCell {

    static let reuseId = "PlaylistTrackCell"

    var onMenuTapped: (() -> Void)?
    var showMenuButton: Bool = true {
        didSet { menuButton.isHidden = !showMenuButton }
    }

    private let thumbView: UIImageView = {
        let v = UIImageView()
        v.image = DefaultCover.audioBackground
        v.contentMode = .scaleAspectFill
        v.layer.cornerRadius = AppColors.cardCornerRadius
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFonts.semibold(16)
        l.textColor = .white
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        l.adjustsFontSizeToFitWidth = false
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFonts.regular(14)
        l.textColor = UIColor.white.withAlphaComponent(0.7)
        l.fitTextWithinBounds(multiline: true)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let menuButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        b.setImage(UIImage(systemName: "ellipsis", withConfiguration: config), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.addSubview(thumbView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(menuButton)
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            thumbView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: 48),
            thumbView.heightAnchor.constraint(equalToConstant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: thumbView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            menuButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            menuButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(title: String, subtitle: String, coverImageURL: URL? = nil) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        thumbView.image = coverImageURL.flatMap { UIImage(contentsOfFile: $0.path) } ?? DefaultCover.audioBackground
    }

    @objc private func menuTapped() {
        onMenuTapped?()
    }
}

final class PlaylistItemPickerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private let items: [MediaItem]
    private let playlistKind: MediaItemKind
    private let onSelect: ([MediaItem]) -> Void
    private var selectedIndexPaths: Set<IndexPath> = []

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.backgroundColor = .clear
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    private let backgroundImageView: UIImageView = {
        let v = UIImageView()
        v.image = UIImage(named: "load_back")
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    init(items: [MediaItem], playlistKind: MediaItemKind, onSelect: @escaping ([MediaItem]) -> Void) {
        self.items = items
        self.playlistKind = playlistKind
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(backgroundImageView)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        navigationItem.title = playlistKind == .video ? AppStrings.addVideo : AppStrings.addTrack
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.leftBarButtonItem?.tintColor = .white
        let addBtn = UIBarButtonItem(title: AppStrings.addSelected, style: .done, target: self, action: #selector(addSelectedTapped))
        addBtn.tintColor = .white
        navigationItem.rightBarButtonItem = addBtn
        updateAddButtonState()
        tableView.allowsMultipleSelection = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PlaylistTrackCell.self, forCellReuseIdentifier: PlaylistTrackCell.reuseId)
    }

    private func updateAddButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = !selectedIndexPaths.isEmpty
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func addSelectedTapped() {
        let selected = selectedIndexPaths.sorted().compactMap { idx -> MediaItem? in
            idx.row < items.count ? items[idx.row] : nil
        }
        guard !selected.isEmpty else { return }
        onSelect(selected)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PlaylistTrackCell.reuseId, for: indexPath) as! PlaylistTrackCell
        let item = items[indexPath.row]
        cell.showMenuButton = false
        cell.configure(title: item.displayTitle, subtitle: item.author ?? "", coverImageURL: item.coverImageURL)
        cell.onMenuTapped = nil
        cell.accessoryType = selectedIndexPaths.contains(indexPath) ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndexPaths.insert(indexPath)
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        updateAddButtonState()
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        selectedIndexPaths.remove(indexPath)
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
        updateAddButtonState()
    }
}
