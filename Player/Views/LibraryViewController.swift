import UIKit
import UniformTypeIdentifiers

final class LibraryViewController: UIViewController, LibraryViewProtocol {

    var presenter: LibraryPresenterProtocol?
    private var items: [MediaItem] = []
    private var playlists: [Playlist] = []
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private let addButton = UIBarButtonItem.touchTargetAdd(target: nil, action: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = AppStrings.library
        view.backgroundColor = .systemGroupedBackground
        table.delegate = self
        table.dataSource = self
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        navigationItem.rightBarButtonItem = addButton
        (addButton.customView as? UIControl)?.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        if presenter == nil {
            presenter = LibraryPresenter(view: self)
        }
        presenter?.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(mediaListDidChange), name: MediaStorageService.mediaListDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pipConversionProgressDidUpdate(_:)), name: MediaStorageService.pipConversionProgressNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func pipConversionProgressDidUpdate(_ note: Notification) {
        guard let itemId = note.userInfo?["itemId"] as? String,
              let row = items.firstIndex(where: { $0.id == itemId }) else { return }
        table.reloadRows(at: [IndexPath(row: row, section: 1)], with: .none)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (presenter as? LibraryPresenter)?.reloadItemsFromStorage()
    }

    @objc private func mediaListDidChange() {
        (presenter as? LibraryPresenter)?.reloadItemsFromStorage()
    }

    @objc private func addTapped() {
        MediaImportService.shared.presentAddSource(from: self, kind: .video)
    }

    func displayItems(_ items: [MediaItem]) {
        self.items = items
        table.reloadData()
    }

    func displayPlaylists(_ playlists: [Playlist]) {
        self.playlists = playlists
        table.reloadData()
    }

    func showError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppStrings.ok, style: .default))
        present(alert, animated: true)
    }

    func openPlayer(_ viewController: UIViewController) {
        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
    }
}

extension LibraryViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return playlists.count + 1
        }
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let id = "Cell"
            let cell = tableView.dequeueReusableCell(withIdentifier: id) ?? UITableViewCell(style: .subtitle, reuseIdentifier: id)
            if indexPath.row == 0 {
                cell.textLabel?.text = AppStrings.newPlaylistLowercase
                cell.detailTextLabel?.text = nil
            } else {
                let p = playlists[indexPath.row - 1]
                cell.textLabel?.text = p.name
                cell.detailTextLabel?.text = AppStrings.itemsCount(p.itemIds.count)
            }
            cell.fitTextLabelsWithinBounds()
            return cell
        }
        let item = items[indexPath.row]
        if item.kind == .video {
            let cell = tableView.dequeueReusableCell(withIdentifier: LibraryMediaTableViewCell.reuseId) as? LibraryMediaTableViewCell
                ?? LibraryMediaTableViewCell(style: .subtitle, reuseIdentifier: LibraryMediaTableViewCell.reuseId)
            cell.configure(video: item)
            cell.fitTextLabelsWithinBounds()
            return cell
        }
        let id = "Cell"
        let cell = tableView.dequeueReusableCell(withIdentifier: id) ?? UITableViewCell(style: .subtitle, reuseIdentifier: id)
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.author
        cell.contentView.alpha = 1
        cell.accessoryView = nil
        cell.fitTextLabelsWithinBounds()
        if indexPath.section == 1 {
            cell.textLabel?.numberOfLines = 1
            cell.textLabel?.lineBreakMode = .byTruncatingTail
            cell.textLabel?.adjustsFontSizeToFitWidth = false
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                presenter?.didRequestNewPlaylist()
            } else {
                presenter?.didSelectPlaylist(playlists[indexPath.row - 1])
            }
        } else {
            presenter?.didSelectItem(items[indexPath.row])
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? AppStrings.playlists : AppStrings.media
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.section == 0 && indexPath.row > 0 {
            let playlist = playlists[indexPath.row - 1]
            let delete = UIContextualAction(style: .destructive, title: AppStrings.delete) { [weak self] _, _, _ in
                self?.presenter?.didRequestDeletePlaylist(playlist)
            }
            let rename = UIContextualAction(style: .normal, title: AppStrings.rename) { [weak self] _, _, _ in
                self?.presenter?.didRequestRenamePlaylist(playlist)
            }
            return UISwipeActionsConfiguration(actions: [delete, rename])
        }
        return nil
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if indexPath.section == 1 {
            let item = items[indexPath.row]
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                let addToPlaylist = UIAction(title: AppStrings.addToPlaylist) { [weak self] _ in
                    self?.presenter?.didRequestAddItemToPlaylist(item)
                }
                return UIMenu(children: [addToPlaylist])
            }
        }
        return nil
    }
}

extension LibraryViewController {

    func showPlaylistNameAlert(completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: AppStrings.newPlaylistLowercase, message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = AppStrings.name }
        alert.addAction(UIAlertAction(title: AppStrings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: AppStrings.create, style: .default) { _ in
            completion(alert.textFields?.first?.text ?? "")
        })
        present(alert, animated: true)
    }

    func showRenamePlaylistAlert(currentName: String, completion: @escaping (String) -> Void) {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.renamePlaylist
        vc.initialText = currentName
        vc.onSave = { name in completion(name) }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    func showPlaylistPicker(playlists: [Playlist], completion: @escaping (Playlist) -> Void) {
        let alert = UIAlertController(title: AppStrings.addToPlaylist, message: nil, preferredStyle: .actionSheet)
        for p in playlists {
            alert.addAction(UIAlertAction(title: p.name, style: .default) { _ in completion(p) })
        }
        alert.addAction(UIAlertAction(title: AppStrings.cancel, style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }
}
