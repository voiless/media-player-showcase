import Foundation
import UIKit

final class LibraryPresenter: LibraryPresenterProtocol {
    weak var view: LibraryViewProtocol?
    private let storage = MediaStorageService.shared
    private var items: [MediaItem] = []
    private var playlists: [Playlist] = []

    init(view: LibraryViewProtocol) {
        self.view = view
    }

    func viewDidLoad() {
        playlists = storage.loadPlaylists()
        reloadItemsFromStorage()
        view?.displayPlaylists(playlists)
    }

    func reloadItemsFromStorage() {
        items = storage.loadVideoItems() + storage.loadAudioItems()
        view?.displayItems(items)
    }

    func addItems(_ newItems: [MediaItem]) {
        for item in newItems {
            if item.kind == .video {
                storage.addVideoItem(item)
            } else {
                storage.addAudioItem(item)
            }
            MediaCoverScheduler.scheduleCoverGeneration(for: item)
            if item.kind == .video, item.url.isFileURL {
                let mediaDir = item.url.deletingLastPathComponent()
                if mediaDir.lastPathComponent == "Media" {
                    let ext = item.url.pathExtension.lowercased()
                    if PiPConversionService.vlcFormatsForPipConversion.contains(ext),
                       item.url.path.hasPrefix(mediaDir.path) {
                        storage.updateVideoItemPipPreparation(id: item.id, state: .pending)
                    }
                    PiPConversionService.shared.schedulePipConversionIfNeeded(for: item, mediaDirectory: mediaDir, completion: nil)
                }
            }
        }
        reloadItemsFromStorage()
    }

    func addPlaylist(name: String) {
        let playlist = Playlist(id: UUID().uuidString, name: name, itemIds: [], createdAt: Date())
        playlists.append(playlist)
        storage.savePlaylists(playlists)
        view?.displayPlaylists(playlists)
    }

    func deletePlaylist(id: String) {
        playlists.removeAll { $0.id == id }
        storage.savePlaylists(playlists)
        view?.displayPlaylists(playlists)
    }

    func renamePlaylist(id: String, name: String) {
        if let i = playlists.firstIndex(where: { $0.id == id }) {
            playlists[i].name = name
            storage.savePlaylists(playlists)
            view?.displayPlaylists(playlists)
        }
    }

    func didSelectItem(_ item: MediaItem) {
        let playerVC = PlayerViewController()
        let presenter = PlayerPresenter(view: playerVC, playerService: PlayerService.shared)
        playerVC.presenter = presenter
        playerVC.setQueue([item], startIndex: 0)
        let nav = PlayerNavigationController(rootViewController: playerVC)
        view?.openPlayer(nav)
    }

    func didSelectPlaylist(_ playlist: Playlist) {
        let ids = Set(playlist.itemIds)
        let playlistItems = items.filter { ids.contains($0.id) }
        if playlistItems.isEmpty {
            view?.showError(AppStrings.playlistIsEmpty)
            return
        }
        let playerVC = PlayerViewController()
        let presenter = PlayerPresenter(view: playerVC, playerService: PlayerService.shared)
        playerVC.presenter = presenter
        playerVC.setQueue(playlistItems, startIndex: 0)
        let nav = PlayerNavigationController(rootViewController: playerVC)
        view?.openPlayer(nav)
    }

    func allItems() -> [MediaItem] {
        return items
    }

    func allPlaylists() -> [Playlist] {
        return playlists
    }

    func didRequestNewPlaylist() {
        view?.showPlaylistNameAlert { [weak self] name in
            guard !name.isEmpty else { return }
            self?.addPlaylist(name: name)
        }
    }

    func didRequestRenamePlaylist(_ playlist: Playlist) {
        view?.showRenamePlaylistAlert(currentName: playlist.name) { [weak self] name in
            guard !name.isEmpty else { return }
            self?.renamePlaylist(id: playlist.id, name: name)
        }
    }

    func didRequestDeletePlaylist(_ playlist: Playlist) {
        deletePlaylist(id: playlist.id)
    }

    func didRequestAddItemToPlaylist(_ item: MediaItem) {
        guard !playlists.isEmpty else {
            view?.showError(AppStrings.createPlaylistFirst)
            return
        }
        view?.showPlaylistPicker(playlists: playlists) { [weak self] playlist in
            self?.addItem(item.id, toPlaylistId: playlist.id)
        }
    }

    private func addItem(_ itemId: String, toPlaylistId playlistId: String) {
        guard let i = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        if playlists[i].itemIds.contains(itemId) { return }
        playlists[i].itemIds.append(itemId)
        storage.savePlaylists(playlists)
        view?.displayPlaylists(playlists)
    }
}
