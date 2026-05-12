import Foundation

final class MediaStorageService {
    static let shared = MediaStorageService()
    static let mediaCoversDidUpdateNotification = Notification.Name("Player.mediaCoversDidUpdate")
    static let mediaListDidChangeNotification = Notification.Name("Player.mediaListDidChange")
    /// userInfo: itemId String, progress Int (0...99)
    static let pipConversionProgressNotification = Notification.Name("Player.pipConversionProgress")
    /// userInfo: itemId String, success Bool
    static let pipConversionFinishedNotification = Notification.Name("Player.pipConversionFinished")
    private let playlistsKey = "Player.playlists"
    private let lastPlaybackKey = "Player.lastPlayback"
    private let lastPlaybackTimeKey = "Player.lastPlaybackTime"
    private let recentVideoIdsKey = "Player.recentVideoIds"
    private let videoItemsKey = "Player.videoItems"
    private let audioItemsKey = "Player.audioItems"
    private let videoBookmarksKey = "Player.videoBookmarks"
    private let audioBookmarksKey = "Player.audioBookmarks"
    private let albumsKey = "Player.albums"
    private let audioAlbumsKey = "Player.audioAlbums"
    private let foldersKey = "Player.folders"
    private let recentAudioIdsKey = "Player.recentAudioIds"
    private let backgroundPlayEnabledKey = "Player.backgroundPlayEnabled"
    private let pipConversionURLsKey = "Player.pipConversionURLs"
    static let onboardingCompletedKey = "onboarding_completed_key"

    private init() {}

    func backgroundPlayEnabled() -> Bool {
        (UserDefaults.standard.object(forKey: backgroundPlayEnabledKey) as? Bool) ?? true
    }

    func setBackgroundPlayEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: backgroundPlayEnabledKey)
    }

    func loadAlbums() -> [Album] {
        guard let data = UserDefaults.standard.data(forKey: albumsKey),
              let decoded = try? JSONDecoder().decode([Album].self, from: data) else { return [] }
        return decoded
    }

    func saveAlbums(_ albums: [Album]) {
        guard let data = try? JSONEncoder().encode(albums) else { return }
        UserDefaults.standard.set(data, forKey: albumsKey)
    }

    func loadAudioAlbums() -> [Album] {
        guard let data = UserDefaults.standard.data(forKey: audioAlbumsKey),
              let decoded = try? JSONDecoder().decode([Album].self, from: data) else { return [] }
        return decoded
    }

    func saveAudioAlbums(_ albums: [Album]) {
        guard let data = try? JSONEncoder().encode(albums) else { return }
        UserDefaults.standard.set(data, forKey: audioAlbumsKey)
    }

    func loadFolders() -> [MediaFolder] {
        guard let data = UserDefaults.standard.data(forKey: foldersKey),
              let decoded = try? JSONDecoder().decode([MediaFolder].self, from: data) else { return [] }
        return decoded
    }

    func saveFolders(_ folders: [MediaFolder]) {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: foldersKey)
    }

    func loadVideoItems() -> [MediaItem] {
        loadMediaItems(key: videoItemsKey, kind: .video)
    }

    func saveVideoItems(_ items: [MediaItem]) {
        saveMediaItems(items, key: videoItemsKey)
    }

    func addVideoItem(_ item: MediaItem) {
        var items = loadVideoItems()
        if !items.contains(where: { $0.id == item.id }) {
            items.append(item)
            saveVideoItems(items)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.mediaListDidChangeNotification, object: nil)
            }
        }
    }

    /// Удаляет файл медиа и соответствующий PiP-MP4 из sandbox (кэш PiP переживает перезапуск приложения, пока элемент в библиотеке).
    func removeVideoItem(id: String) {
        if let pipURL = loadPipConversionURL(itemId: id) {
            try? FileManager.default.removeItem(at: pipURL)
        }
        var urls = loadPipConversionURLs()
        urls.removeValue(forKey: id)
        savePipConversionURLs(urls)
        var items = loadVideoItems()
        items.removeAll { $0.id == id }
        saveVideoItems(items)
    }

    func savePipConversionURL(itemId: String, url: URL) {
        var urls = loadPipConversionURLs()
        urls[itemId] = url.path
        savePipConversionURLs(urls)
    }

    func loadPipConversionURL(itemId: String) -> URL? {
        let urls = loadPipConversionURLs()
        guard let path = urls[itemId], !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Map в UserDefaults или ожидаемый путь `Media/PiP` на диске (починка рассинхрона после конвертации).
    func resolvePipConversionURL(itemId: String, mediaDirectory: URL) -> URL? {
        if let u = loadPipConversionURL(itemId: itemId) { return u }
        let candidate = PiPConversionService.shared.destinationMP4URL(forItemId: itemId, mediaDirectory: mediaDirectory)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return nil }
        savePipConversionURL(itemId: itemId, url: candidate)
        return candidate
    }

    private func loadPipConversionURLs() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: pipConversionURLsKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return decoded
    }

    private func savePipConversionURLs(_ urls: [String: String]) {
        guard let data = try? JSONEncoder().encode(urls) else { return }
        UserDefaults.standard.set(data, forKey: pipConversionURLsKey)
    }

    /// Одноразовая инвалидация кэша PiP-MP4 после смены пайплайна (720p / 3.5M, прогресс по времени, и т.д.).
    /// Массовое удаление файлов только здесь — при bump `pipConversionOutputFormatVersion`; обычный перезапуск приложения кэш не трогает.
    func migratePipConversionCacheIfNeeded() {
        let versionKey = "Player.pipConversionOutputFormatVersion"
        let currentVersion = 4
        guard UserDefaults.standard.integer(forKey: versionKey) < currentVersion else { return }
        let urls = loadPipConversionURLs()
        for (_, path) in urls {
            try? FileManager.default.removeItem(atPath: path)
        }
        savePipConversionURLs([:])
        UserDefaults.standard.set(currentVersion, forKey: versionKey)
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let mediaDir = docs.appendingPathComponent("Media", isDirectory: true)
        for item in loadVideoItems() {
            let ext = item.url.pathExtension.lowercased()
            guard PiPConversionService.vlcFormatsForPipConversion.contains(ext),
                  item.url.isFileURL, item.url.path.hasPrefix(mediaDir.path) else { continue }
            updateVideoItemPipPreparation(id: item.id, state: .pending)
            PiPConversionService.shared.schedulePipConversionIfNeeded(for: item, mediaDirectory: mediaDir, completion: nil)
        }
    }

    func loadAudioItems() -> [MediaItem] {
        loadMediaItems(key: audioItemsKey, kind: .audio)
    }

    func saveAudioItems(_ items: [MediaItem]) {
        saveMediaItems(items, key: audioItemsKey)
    }

    func addAudioItem(_ item: MediaItem) {
        var items = loadAudioItems()
        if !items.contains(where: { $0.id == item.id }) {
            items.append(item)
            saveAudioItems(items)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.mediaListDidChangeNotification, object: nil)
            }
        }
    }

    func updateItemStatus(id: String, status: MediaItemStatus) {
        var videoItems = loadVideoItems()
        if let idx = videoItems.firstIndex(where: { $0.id == id }) {
            videoItems[idx].status = status
            saveVideoItems(videoItems)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.mediaListDidChangeNotification, object: nil)
            }
            return
        }
        var audioItems = loadAudioItems()
        if let idx = audioItems.firstIndex(where: { $0.id == id }) {
            audioItems[idx].status = status
            saveAudioItems(audioItems)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.mediaListDidChangeNotification, object: nil)
            }
        }
    }

    func updateVideoItemPipPreparation(id: String, state: PipPreparationState) {
        var videoItems = loadVideoItems()
        guard let idx = videoItems.firstIndex(where: { $0.id == id }) else { return }
        videoItems[idx].pipPreparation = state
        saveVideoItems(videoItems)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.mediaListDidChangeNotification, object: nil)
        }
    }

    /// Перезапуск фоновой конвертации PiP для элементов в `.pending` без готового файла (после миграции или сбоя).
    func reschedulePendingPipConversionsIfNeeded() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let mediaDir = docs.appendingPathComponent("Media", isDirectory: true)
        for item in loadVideoItems() {
            guard item.pipPreparation == .pending else { continue }
            let ext = item.url.pathExtension.lowercased()
            guard PiPConversionService.vlcFormatsForPipConversion.contains(ext),
                  item.url.isFileURL, item.url.path.hasPrefix(mediaDir.path) else { continue }
            if loadPipConversionURL(itemId: item.id) != nil {
                updateVideoItemPipPreparation(id: item.id, state: .ready)
                continue
            }
            PiPConversionService.shared.schedulePipConversionIfNeeded(for: item, mediaDirectory: mediaDir, completion: nil)
        }
    }

    func removeAudioItem(id: String) {
        var items = loadAudioItems()
        items.removeAll { $0.id == id }
        saveAudioItems(items)
    }

    func updateAudioItemCover(id: String, coverURL: URL) {
        var items = loadAudioItems()
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].coverImageURL = coverURL
        saveAudioItems(items)
    }

    func updateVideoItemCover(id: String, coverURL: URL) {
        var items = loadVideoItems()
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].coverImageURL = coverURL
        saveVideoItems(items)
    }

    func mediaItem(byId id: String) -> MediaItem? {
        loadVideoItems().first { $0.id == id } ?? loadAudioItems().first { $0.id == id }
    }

    private struct MediaItemStore: Codable {
        let id: String
        let urlPath: String
        let kind: String
        var title: String
        var author: String?
        var coverImagePath: String?
        var duration: TimeInterval
        var status: String?
        var pipPreparation: String?
    }

    private func loadMediaItems(key: String, kind: MediaItemKind) -> [MediaItem] {
        let bookmarksKey = kind == .video ? videoBookmarksKey : audioBookmarksKey
        let bookmarks = loadBookmarks(key: bookmarksKey)
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MediaItemStore].self, from: data) else { return [] }
        let fm = FileManager.default
        var needsPersistPipMigration = false
        let result = decoded.compactMap { store -> MediaItem? in
            var url: URL?
            if let u = URL(string: store.urlPath), fm.fileExists(atPath: u.path) {
                url = u
            } else if let bookmarkData = bookmarks[store.id] {
                var isStale = false
                if let u = try? URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                    _ = u.startAccessingSecurityScopedResource()
                    url = u
                }
            }
            guard let resolvedURL = url else { return nil }
            let coverURL: URL? = store.coverImagePath.flatMap { path in
                if path.contains("/") {
                    let existing = URL(fileURLWithPath: path)
                    return FileManager.default.fileExists(atPath: existing.path) ? existing : MediaCoverCache.coverURL(forFilename: (path as NSString).lastPathComponent)
                }
                return MediaCoverCache.coverURL(forFilename: path)
            }
            var status = MediaItemStatus(rawValue: store.status ?? "") ?? .ready
            let pipPreparation: PipPreparationState
            if kind == .audio {
                pipPreparation = .notApplicable
            } else if let raw = store.pipPreparation, let p = PipPreparationState(rawValue: raw) {
                pipPreparation = p
            } else {
                needsPersistPipMigration = true
                let ext = resolvedURL.pathExtension.lowercased()
                let needsPip = PiPConversionService.vlcFormatsForPipConversion.contains(ext)
                if !needsPip {
                    pipPreparation = .notApplicable
                } else if loadPipConversionURL(itemId: store.id) != nil {
                    pipPreparation = .ready
                    if status == .processing || status == .error { status = .ready }
                } else {
                    switch status {
                    case .processing:
                        pipPreparation = .pending
                        status = .ready
                    case .error:
                        pipPreparation = .failed
                        status = .ready
                    case .ready:
                        pipPreparation = .pending
                    }
                }
            }
            return MediaItem(id: store.id, url: resolvedURL, kind: kind, title: store.title, author: store.author, coverImageURL: coverURL, duration: store.duration, status: status, pipPreparation: pipPreparation)
        }
        if needsPersistPipMigration, !result.isEmpty {
            saveMediaItems(result, key: key)
        }
        return result
    }

    private func loadBookmarks(key: String) -> [String: Data] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Data].self, from: data) else { return [:] }
        return decoded
    }

    private func saveBookmarks(_ bookmarks: [String: Data], key: String) {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func saveMediaItems(_ items: [MediaItem], key: String) {
        let bookmarksKey = key == videoItemsKey ? videoBookmarksKey : audioBookmarksKey
        var bookmarks = loadBookmarks(key: bookmarksKey)
        for item in items where item.url.isFileURL {
            if let bookmarkData = try? item.url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
                bookmarks[item.id] = bookmarkData
            }
        }
        let ids = Set(items.map(\.id))
        bookmarks = bookmarks.filter { ids.contains($0.key) }
        saveBookmarks(bookmarks, key: bookmarksKey)
        let stores = items.map { item in
            let coverPath = item.coverImageURL.flatMap { url -> String? in
                let name = url.lastPathComponent
                return name.isEmpty ? nil : name
            }
            let pipStr = item.kind == .video ? item.pipPreparation.rawValue : nil
            return MediaItemStore(id: item.id, urlPath: item.url.absoluteString, kind: item.kind.rawValue, title: item.title, author: item.author, coverImagePath: coverPath, duration: item.duration, status: item.status.rawValue, pipPreparation: pipStr)
        }
        guard let data = try? JSONEncoder().encode(stores) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func loadPlaylists() -> [Playlist] {
        guard let data = UserDefaults.standard.data(forKey: playlistsKey),
              let decoded = try? JSONDecoder().decode([Playlist].self, from: data) else { return [] }
        return decoded
    }

    func savePlaylists(_ playlists: [Playlist]) {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        UserDefaults.standard.set(data, forKey: playlistsKey)
    }

    func saveLastPlayback(itemId: String, time: TimeInterval) {
        UserDefaults.standard.set(itemId, forKey: lastPlaybackKey)
        UserDefaults.standard.set(time, forKey: lastPlaybackTimeKey)
        if let item = mediaItem(byId: itemId) {
            if item.kind == .audio {
                addToRecentAudioHistory(itemId: itemId)
            } else {
                addToRecentVideoHistory(itemId: itemId)
            }
        }
    }

    func loadLastPlayback() -> (itemId: String, time: TimeInterval)? {
        guard let id = UserDefaults.standard.string(forKey: lastPlaybackKey) else { return nil }
        let time = UserDefaults.standard.double(forKey: lastPlaybackTimeKey)
        return (id, time)
    }

    func clearLastPlayback(itemId: String) {
        guard let last = UserDefaults.standard.string(forKey: lastPlaybackKey), last == itemId else { return }
        UserDefaults.standard.removeObject(forKey: lastPlaybackKey)
        UserDefaults.standard.removeObject(forKey: lastPlaybackTimeKey)
    }

    private let maxRecentVideoCount = 100

    func loadRecentVideoIds() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: recentVideoIdsKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return decoded
    }

    private func saveRecentVideoIds(_ ids: [String]) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: recentVideoIdsKey)
    }

    func addToRecentVideoHistory(itemId: String) {
        var ids = loadRecentVideoIds()
        ids.removeAll { $0 == itemId }
        ids.insert(itemId, at: 0)
        saveRecentVideoIds(Array(ids.prefix(maxRecentVideoCount)))
    }

    func removeFromRecentVideoHistory(itemId: String) {
        var ids = loadRecentVideoIds()
        ids.removeAll { $0 == itemId }
        saveRecentVideoIds(ids)
    }

    private let maxRecentAudioCount = 100

    func loadRecentAudioIds() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: recentAudioIdsKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return decoded
    }

    private func saveRecentAudioIds(_ ids: [String]) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: recentAudioIdsKey)
    }

    func addToRecentAudioHistory(itemId: String) {
        var ids = loadRecentAudioIds()
        ids.removeAll { $0 == itemId }
        ids.insert(itemId, at: 0)
        saveRecentAudioIds(Array(ids.prefix(maxRecentAudioCount)))
    }

    func removeFromRecentAudioHistory(itemId: String) {
        var ids = loadRecentAudioIds()
        ids.removeAll { $0 == itemId }
        saveRecentAudioIds(ids)
    }

    func clearAllMediaData() {
        let fm = FileManager.default
        for (_, path) in loadPipConversionURLs() {
            if fm.fileExists(atPath: path) { try? fm.removeItem(atPath: path) }
        }
        savePipConversionURLs([:])
        saveVideoItems([])
        saveAudioItems([])
        savePlaylists([])
        saveAlbums([])
        saveAudioAlbums([])
        saveFolders([])
        saveRecentVideoIds([])
        saveRecentAudioIds([])
        UserDefaults.standard.removeObject(forKey: lastPlaybackKey)
        UserDefaults.standard.removeObject(forKey: lastPlaybackTimeKey)
    }
}
