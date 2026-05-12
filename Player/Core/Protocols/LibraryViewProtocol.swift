import Foundation

import UIKit

protocol LibraryViewProtocol: AnyObject {
    func displayItems(_ items: [MediaItem])
    func displayPlaylists(_ playlists: [Playlist])
    func showError(_ message: String)
    func openPlayer(_ viewController: UIViewController)
    func showPlaylistNameAlert(completion: @escaping (String) -> Void)
    func showRenamePlaylistAlert(currentName: String, completion: @escaping (String) -> Void)
    func showPlaylistPicker(playlists: [Playlist], completion: @escaping (Playlist) -> Void)
}
