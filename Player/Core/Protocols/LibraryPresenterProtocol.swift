import Foundation

protocol LibraryPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didSelectItem(_ item: MediaItem)
    func didSelectPlaylist(_ playlist: Playlist)
    func didRequestNewPlaylist()
    func didRequestRenamePlaylist(_ playlist: Playlist)
    func didRequestDeletePlaylist(_ playlist: Playlist)
    func didRequestAddItemToPlaylist(_ item: MediaItem)
}
