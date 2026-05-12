import UIKit

protocol AudioAlbumDetailViewControllerDelegate: AnyObject {
    func audioAlbumDetailDidUpdate()
}

final class AudioAlbumDetailViewController: UIViewController {

    weak var delegate: AudioAlbumDetailViewControllerDelegate?

    private var album: Album
    private var itemIds: [String] = []
    var showAddTrackOnAppear = false

    var onPlayAudio: (([MediaItem], Int) -> Void)?

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

    init(album: Album) {
        self.album = album
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
        navigationItem.title = album.name
        navigationItem.rightBarButtonItem = UIBarButtonItem.touchTargetAdd(target: self, action: #selector(addTrackTapped))
        navigationItem.rightBarButtonItem?.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.barTintColor = .black
        navigationController?.navigationBar.isTranslucent = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AudioAlbumTrackCell.self, forCellReuseIdentifier: AudioAlbumTrackCell.reuseId)
        reloadAlbum()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        reloadAlbum()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if showAddTrackOnAppear {
            showAddTrackOnAppear = false
            DispatchQueue.main.async { [weak self] in
                self?.addTrackTapped()
            }
        }
    }

    private func reloadAlbum() {
        let albums = MediaStorageService.shared.loadAudioAlbums()
        guard let idx = albums.firstIndex(where: { $0.id == album.id }) else { return }
        album = albums[idx]
        itemIds = album.itemIds
        tableView.reloadData()
    }

    @objc private func backTapped() {
        delegate?.audioAlbumDetailDidUpdate()
        navigationController?.popViewController(animated: true)
    }

    @objc private func addTrackTapped() {
        reloadAlbum()
        let allAudio = MediaStorageService.shared.loadAudioItems()
        let existingIds = Set(album.itemIds)
        let available = allAudio.filter { !existingIds.contains($0.id) }
        if available.isEmpty {
            let alert = UIAlertController(title: nil, message: AppStrings.noTracksAvailableToAdd, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: AppStrings.ok, style: .default))
            present(alert, animated: true)
            return
        }
        showFullTrackPicker(available: available)
    }

    private func showFullTrackPicker(available: [MediaItem]) {
        let listVC = AudioTrackPickerViewController(items: available) { [weak self] selectedItems in
            self?.dismiss(animated: true)
            self?.addTracksToAlbum(selectedItems)
        }
        let nav = UINavigationController(rootViewController: listVC)
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

    private func addTrackToAlbum(_ item: MediaItem) {
        addTracksToAlbum([item])
    }

    private func addTracksToAlbum(_ selectedItems: [MediaItem]) {
        guard !selectedItems.isEmpty else { return }
        var albums = MediaStorageService.shared.loadAudioAlbums()
        guard let idx = albums.firstIndex(where: { $0.id == album.id }) else { return }
        let existingSet = Set(albums[idx].itemIds)
        for item in selectedItems where !existingSet.contains(item.id) {
            albums[idx].itemIds.append(item.id)
        }
        MediaStorageService.shared.saveAudioAlbums(albums)
        album = albums[idx]
        itemIds = album.itemIds
        tableView.reloadData()
        reloadAlbum()
    }

    private func removeTrackFromAlbum(at indexPath: IndexPath) {
        guard indexPath.row < itemIds.count else { return }
        let idToRemove = itemIds[indexPath.row]
        var albums = MediaStorageService.shared.loadAudioAlbums()
        guard let idx = albums.firstIndex(where: { $0.id == album.id }) else { return }
        albums[idx].itemIds.removeAll { $0 == idToRemove }
        MediaStorageService.shared.saveAudioAlbums(albums)
        album = albums[idx]
        itemIds = album.itemIds
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}

extension AudioAlbumDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        itemIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AudioAlbumTrackCell.reuseId, for: indexPath) as! AudioAlbumTrackCell
        let itemId = itemIds[indexPath.row]
        let item = MediaStorageService.shared.mediaItem(byId: itemId)
        cell.configure(title: item.map { $0.displayTitle } ?? AppStrings.unknown, subtitle: item?.author, coverURL: item?.coverImageURL)
        cell.onMenuTapped = { [weak self] in
            self?.showItemOptions(indexPath: indexPath)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let items = itemIds.compactMap { MediaStorageService.shared.mediaItem(byId: $0) }
        guard indexPath.row < items.count else { return }
        onPlayAudio?(items, indexPath.row)
    }

    private func showItemOptions(indexPath: IndexPath) {
        let sheet = UIAlertController(title: AppStrings.selectionOfChanges, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: AppStrings.removeFromAlbum, style: .destructive) { [weak self] _ in
            self?.removeTrackFromAlbum(at: indexPath)
        })
        sheet.addAction(UIAlertAction(title: AppStrings.cancel, style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        present(sheet, animated: true)
    }
}

private final class AudioAlbumTrackCell: UITableViewCell {
    static let reuseId = "AudioAlbumTrackCell"
    var onMenuTapped: (() -> Void)?
    var showMenuButton: Bool = true {
        didSet { menuButton.isHidden = !showMenuButton }
    }

    private let thumbView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.layer.cornerRadius = AppColors.cardCornerRadius
        v.clipsToBounds = true
        v.backgroundColor = UIColor(white: 0.2, alpha: 1)
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

    required init?(coder: NSCoder) { nil }

    func configure(title: String, subtitle: String?, coverURL: URL?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle ?? ""
        thumbView.image = coverURL.flatMap { UIImage(contentsOfFile: $0.path) } ?? DefaultCover.audioBackground
    }

    @objc private func menuTapped() { onMenuTapped?() }
}

private final class AudioTrackPickerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let items: [MediaItem]
    private let onSelect: ([MediaItem]) -> Void
    private var selectedIndexPaths: Set<IndexPath> = []
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
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    init(items: [MediaItem], onSelect: @escaping ([MediaItem]) -> Void) {
        self.items = items
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
        navigationItem.title = AppStrings.addTrack
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.leftBarButtonItem?.tintColor = .white
        let addBtn = UIBarButtonItem(title: AppStrings.addSelected, style: .done, target: self, action: #selector(addSelectedTapped))
        addBtn.tintColor = .white
        navigationItem.rightBarButtonItem = addBtn
        updateAddButtonState()
        tableView.allowsMultipleSelection = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AudioAlbumTrackCell.self, forCellReuseIdentifier: AudioAlbumTrackCell.reuseId)
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
        let cell = tableView.dequeueReusableCell(withIdentifier: AudioAlbumTrackCell.reuseId, for: indexPath) as! AudioAlbumTrackCell
        let item = items[indexPath.row]
        cell.showMenuButton = false
        cell.configure(title: item.displayTitle, subtitle: item.author, coverURL: item.coverImageURL)
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
