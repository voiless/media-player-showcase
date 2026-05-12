import UIKit

protocol FolderDetailViewControllerDelegate: AnyObject {
    func folderDetailDidUpdate()
}

final class FolderDetailViewController: UIViewController {

    weak var delegate: FolderDetailViewControllerDelegate?

    private var folder: MediaFolder
    private var itemIds: [String] = []

    var onPlayVideo: (([MediaItem], Int) -> Void)?

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

    init(folder: MediaFolder) {
        self.folder = folder
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
        navigationItem.title = folder.name
        navigationItem.rightBarButtonItem = UIBarButtonItem.touchTargetAdd(target: self, action: #selector(addVideoTapped))
        navigationItem.rightBarButtonItem?.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.barTintColor = .black
        navigationController?.navigationBar.isTranslucent = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 60
        tableView.estimatedRowHeight = 60
        tableView.register(FolderVideoCell.self, forCellReuseIdentifier: FolderVideoCell.reuseId)
        reloadFolder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        reloadFolder()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if showAddVideoOnAppear {
            showAddVideoOnAppear = false
            DispatchQueue.main.async { [weak self] in
                self?.addVideoTapped()
            }
        }
    }

    var showAddVideoOnAppear = false

    private func reloadFolder() {
        let folders = MediaStorageService.shared.loadFolders()
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folder = folders[idx]
        itemIds = folder.itemIds
        tableView.reloadData()
    }

    @objc private func backTapped() {
        delegate?.folderDetailDidUpdate()
        navigationController?.popViewController(animated: true)
    }

    @objc private func addVideoTapped() {
        reloadFolder()
        let allVideos = MediaStorageService.shared.loadVideoItems()
        let existingIds = Set(folder.itemIds)
        let available = allVideos.filter { !existingIds.contains($0.id) }
        if available.isEmpty {
            let alert = UIAlertController(title: nil, message: AppStrings.noVideosAvailableToAdd, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: AppStrings.ok, style: .default))
            present(alert, animated: true)
            return
        }
        showFullVideoPicker(available: available)
    }

    private func showFullVideoPicker(available: [MediaItem]) {
        let listVC = FolderVideoPickerViewController(items: available) { [weak self] selectedItems in
            self?.dismiss(animated: true)
            self?.addVideosToFolder(selectedItems)
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

    private func addVideoToFolder(_ item: MediaItem) {
        addVideosToFolder([item])
    }

    private func addVideosToFolder(_ selectedItems: [MediaItem]) {
        guard !selectedItems.isEmpty else { return }
        var folders = MediaStorageService.shared.loadFolders()
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        let existingSet = Set(folders[idx].itemIds)
        for item in selectedItems where !existingSet.contains(item.id) {
            folders[idx].itemIds.append(item.id)
        }
        MediaStorageService.shared.saveFolders(folders)
        folder = folders[idx]
        itemIds = folder.itemIds
        tableView.reloadData()
        reloadFolder()
    }

    private func removeVideoFromFolder(itemId: String) {
        var folders = MediaStorageService.shared.loadFolders()
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].itemIds.removeAll { $0 == itemId }
        MediaStorageService.shared.saveFolders(folders)
        folder = folders[idx]
        itemIds = folder.itemIds
        tableView.reloadData()
    }
}

extension FolderDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        itemIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FolderVideoCell.reuseId, for: indexPath) as! FolderVideoCell
        let itemId = itemIds[indexPath.row]
        let item = MediaStorageService.shared.mediaItem(byId: itemId)
        cell.configure(title: item.map { $0.displayTitle } ?? AppStrings.unknown, coverURL: item?.coverImageURL)
        cell.onMenuTapped = { [weak self] in
            self?.showItemOptions(itemId: itemId)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let items = itemIds.compactMap { MediaStorageService.shared.mediaItem(byId: $0) }
        guard indexPath.row < items.count else { return }
        onPlayVideo?(items, indexPath.row)
    }

    private func showItemOptions(itemId: String) {
        let sheet = UIAlertController(title: AppStrings.selectionOfChanges, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: AppStrings.removeFromFolder, style: .destructive) { [weak self] _ in
            self?.removeVideoFromFolder(itemId: itemId)
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

private final class FolderVideoCell: UITableViewCell {

    static let reuseId = "FolderVideoCell"

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

    private let titleScrollView: UIScrollView = {
        let s = UIScrollView()
        s.showsHorizontalScrollIndicator = true
        s.showsVerticalScrollIndicator = false
        s.alwaysBounceHorizontal = true
        s.clipsToBounds = true
        s.isUserInteractionEnabled = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFonts.semibold(16)
        l.textColor = .white
        l.numberOfLines = 1
        l.lineBreakMode = .byClipping
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var titleLabelWidthConstraint: NSLayoutConstraint?

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
        contentView.addSubview(titleScrollView)
        titleScrollView.addSubview(titleLabel)
        contentView.addSubview(menuButton)
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        let titleW = titleLabel.widthAnchor.constraint(equalToConstant: 0)
        titleLabelWidthConstraint = titleW
        NSLayoutConstraint.activate([
            thumbView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            thumbView.widthAnchor.constraint(equalToConstant: 48),
            thumbView.heightAnchor.constraint(equalToConstant: 48),
            thumbView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            titleScrollView.leadingAnchor.constraint(equalTo: thumbView.trailingAnchor, constant: 12),
            titleScrollView.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8),
            titleScrollView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleScrollView.heightAnchor.constraint(equalToConstant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: titleScrollView.contentLayoutGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: titleScrollView.contentLayoutGuide.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: titleScrollView.contentLayoutGuide.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: titleScrollView.contentLayoutGuide.bottomAnchor),
            titleW,
            menuButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            menuButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scrollW = titleScrollView.bounds.width
        guard scrollW > 0 else { return }
        let textW = ceil(titleLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 24)).width)
        let labelW = max(textW, scrollW)
        titleLabelWidthConstraint?.constant = labelW
        titleScrollView.contentSize = CGSize(width: labelW, height: titleScrollView.bounds.height)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleScrollView.contentOffset = .zero
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(title: String, coverURL: URL?) {
        titleLabel.text = title
        thumbView.image = coverURL.flatMap { UIImage(contentsOfFile: $0.path) } ?? DefaultCover.videoCover
    }

    @objc private func menuTapped() {
        onMenuTapped?()
    }
}

private final class FolderVideoPickerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

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
        navigationItem.title = AppStrings.addVideo
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.leftBarButtonItem?.tintColor = .white
        let addBtn = UIBarButtonItem(title: AppStrings.addSelected, style: .done, target: self, action: #selector(addSelectedTapped))
        addBtn.tintColor = .white
        navigationItem.rightBarButtonItem = addBtn
        updateAddButtonState()
        tableView.allowsMultipleSelection = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 60
        tableView.estimatedRowHeight = 60
        tableView.register(FolderVideoCell.self, forCellReuseIdentifier: FolderVideoCell.reuseId)
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FolderVideoCell.reuseId, for: indexPath) as! FolderVideoCell
        let item = items[indexPath.row]
        cell.showMenuButton = false
        cell.configure(title: item.displayTitle, coverURL: item.coverImageURL)
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
