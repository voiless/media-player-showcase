import Foundation

enum AppStrings {

    private static let preferredLanguageKey = "AppPreferredLanguageCode"

    static let languageCodes = ["ru", "en", "fr", "pt-PT", "es", "de"]

    static var preferredLanguageCode: String? {
        get { UserDefaults.standard.string(forKey: preferredLanguageKey) }
        set { UserDefaults.standard.set(newValue, forKey: preferredLanguageKey) }
    }

    private static func bundleForCurrentLanguage() -> Bundle {
        guard let code = preferredLanguageCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }

    private static func L(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundleForCurrentLanguage(), value: key, comment: "")
    }

    static var selectFile: String { L("selectFile") }
    static var library: String { L("library") }
    static var player: String { L("player") }
    static var ok: String { L("ok") }
    static var cancel: String { L("cancel") }
    static var save: String { L("save") }
    static var name: String { L("name") }
    static var create: String { L("create") }
    static var unknown: String { L("unknown") }
    static var track: String { L("track") }
    static var tracks: String { L("tracks") }
    static var rename: String { L("rename") }
    static var delete: String { L("delete") }
    static var placeholder: String { L("placeholder") }
    static var settings: String { L("settings") }
    static var playlist: String { L("playlist") }
    static var newPlaylist: String { L("newPlaylist") }
    static var video: String { L("video") }
    static var audio: String { L("audio") }
    static var myPlaylist: String { L("myPlaylist") }
    static var nameApp: String {
        if let n = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !n.trimmingCharacters(in: .whitespaces).isEmpty {
            return n
        }
        if let n = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !n.trimmingCharacters(in: .whitespaces).isEmpty {
            return n
        }
        return L("nameApp")
    }
    static var loadingScreenTitle: String { L("loadingScreenTitle") }
    static var search: String { L("search") }
    static var songs: String { L("songs") }
    static var album: String { L("album") }
    static var artists: String { L("artists") }
    static var recent: String { L("recent") }
    static var folder: String { L("folder") }
    static var thereAreNoFilesAvailable: String { L("thereAreNoFilesAvailable") }
    static var clickPlusToCreateAndOrganize: String { L("clickPlusToCreateAndOrganize") }
    static var noArtists: String { L("noArtists") }
    static var newAlbum: String { L("newAlbum") }
    static var newFolder: String { L("newFolder") }
    static var selectionOfChanges: String { L("selectionOfChanges") }
    static var areYouSure: String { L("areYouSure") }
    static var confirmFileDeletion: String { L("confirmFileDeletion") }
    static var chooseTitleForNewPlaylist: String { L("chooseTitleForNewPlaylist") }
    static var videoPlaylist: String { L("videoPlaylist") }
    static var audioPlaylist: String { L("audioPlaylist") }
    static var addVideo: String { L("addVideo") }
    static var addTrack: String { L("addTrack") }
    static var addSelected: String { L("addSelected") }
    static var noVideosAvailableToAdd: String { L("noVideosAvailableToAdd") }
    static var noTracksAvailableToAdd: String { L("noTracksAvailableToAdd") }
    static var noAudioTracksAvailableToAdd: String { L("noAudioTracksAvailableToAdd") }
    static var removeFromAlbum: String { L("removeFromAlbum") }
    static var removeFromFolder: String { L("removeFromFolder") }
    static var pictureInPicture: String { L("pictureInPicture") }
    static var pipNotSupportedFormat: String { L("pipNotSupportedFormat") }
    static var pipNotSupportedDevice: String { L("pipNotSupportedDevice") }
    static var pipNotReady: String { L("pipNotReady") }
    static var pipPreparing: String { L("pipPreparing") }
    static var pipPreparingTryLater: String { L("pipPreparingTryLater") }
    static var pipConversionFailed: String { L("pipConversionFailed") }
    static var pipNotAvailableAddAgain: String { L("pipNotAvailableAddAgain") }
    static var pipTranscodeMp4PlaybackFailed: String { L("pipTranscodeMp4PlaybackFailed") }
    static var libraryPipPreparing: String { L("libraryPipPreparing") }
    static var libraryPipConversionErrorShort: String { L("libraryPipConversionErrorShort") }
    static var pipConversionProgressPhase: String { L("pipConversionProgressPhase") }

    static func pipPreparingProgressLabel(percent: Int) -> String {
        String(format: L("pipPreparingProgressFormat"), pipConversionProgressPhase, percent)
    }
    static var share: String { L("share") }
    static var subtitleTrack: String { L("subtitleTrack") }
    static var noSubtitleTracks: String { L("noSubtitleTracks") }
    static var off: String { L("off") }
    static var audioTrack: String { L("audioTrack") }
    static var noAlternateAudio: String { L("noAlternateAudio") }
    static var nameFile: String { L("nameFile") }
    static var timeZero: String { L("timeZero") }
    static var timeMinusZero: String { L("timeMinusZero") }
    static func brightnessValue(percent: Int) -> String {
        String(format: L("brightnessValueFormat"), percent)
    }
    static var dash: String { L("dash") }
    static var videos: String { L("videos") }
    static var forEasyViewing: String { L("forEasyViewing") }
    static var continue_: String { L("continue_") }
    static var onboardingBodyText: String { L("onboardingBodyText") }
    static var music: String { L("music") }
    static var forYourWellbeing: String { L("forYourWellbeing") }
    static var toBoostYourEnergy: String { L("toBoostYourEnergy") }
    static var start3DaysForFree: String { L("start3DaysForFree") }
    static var onboardingThenPricePerWeek: String { L("onboardingThenPricePerWeek") }
    static var closeSymbol: String { L("closeSymbol") }
    static var restore: String { L("restore") }
    static var termsOfUse: String { L("termsOfUse") }
    static var and: String { L("and") }
    static var privacyPolicy: String { L("privacyPolicy") }
    static var playlistIsEmpty: String { L("playlistIsEmpty") }
    static var createPlaylistFirst: String { L("createPlaylistFirst") }
    static var couldNotAddVideo: String { L("couldNotAddVideo") }
    static var couldNotAddAudio: String { L("couldNotAddAudio") }
    static var cannotOpen: String { L("cannotOpen") }
    static var fileCouldNotBeOpened: String { L("fileCouldNotBeOpened") }
    static var fileCouldNotBeOpenedHint: String { L("fileCouldNotBeOpenedHint") }
    static var backgroundPlay: String { L("backgroundPlay") }
    static var language: String { L("language") }
    static var feedback: String { L("feedback") }
    static var feedbackEmail: String { L("feedbackEmail") }
    static var appSupportURL: String { L("appSupportURL") }
    static var termsOfUseURL: String { L("termsOfUseURL") }
    static var privacyPolicyURL: String { L("privacyPolicyURL") }
    static var rateAppURL: String { L("rateAppURL") }
    static var clearCache: String { L("clearCache") }
    static var clearCacheConfirmTitle: String { L("clearCacheConfirmTitle") }
    static var clearCacheConfirmMessage: String { L("clearCacheConfirmMessage") }
    static var clear: String { L("clear") }
    static var rateTheApp: String { L("rateTheApp") }
    static var restoringPurchases: String { L("restoringPurchases") }
    static var restoreSuccess: String { L("restoreSuccess") }
    static var restoreFailed: String { L("restoreFailed") }
    static var portfolioDemos: String { L("portfolioDemos") }
    static var joinSupport: String { L("joinSupport") }
    static var activeCommunityCount: String { L("activeCommunityCount") }
    static var install: String { L("install") }
    static var playlists: String { L("playlists") }
    static var media: String { L("media") }
    static var newPlaylistLowercase: String { L("newPlaylistLowercase") }
    static var addToPlaylist: String { L("addToPlaylist") }
    static var renamePlaylist: String { L("renamePlaylist") }
    static var files: String { L("files") }
    static var addFolder: String { L("addFolder") }
    static var getPro: String { L("getPro") }
    static var selectingTransmittingDevice: String { L("selectingTransmittingDevice") }
    static var airPlayOrBluetooth: String { L("airPlayOrBluetooth") }
    static var transmittingDevices: String { L("transmittingDevices") }
    static var trackOption: String { L("trackOption") }
    static var addVideoFrom: String { L("addVideoFrom") }
    static var addAudioFrom: String { L("addAudioFrom") }
    static var fileIsProcessing: String { L("fileIsProcessing") }

    static var getPremiumAccess: String { L("getPremiumAccess") }
    static var fullAccessToAllFunctions: String { L("fullAccessToAllFunctions") }
    static var freeTrialEnabled: String { L("freeTrialEnabled") }
    static var weekly: String { L("weekly") }
    static var yearly: String { L("yearly") }
    static var perWeek: String { L("perWeek") }
    static var perYear: String { L("perYear") }
    static var theBestOffer: String { L("theBestOffer") }
    static var startTryFreeTrial: String { L("startTryFreeTrial") }
    static var termsOfUseAndPrivacyPolicy: String { L("termsOfUseAndPrivacyPolicy") }
    static var defaultWeeklyPrice: String { L("defaultWeeklyPrice") }
    static var defaultYearlyPrice: String { L("defaultYearlyPrice") }
    static var exitAppConfirmTitle: String { L("exitAppConfirmTitle") }
    static var exitAppConfirmMessage: String { L("exitAppConfirmMessage") }
    static var exit: String { L("exit") }

    static var languageRussian: String { L("languageRussian") }
    static var languageEnglish: String { L("languageEnglish") }
    static var languageFrench: String { L("languageFrench") }
    static var languagePortugal: String { L("languagePortugal") }
    static var languageSpanish: String { L("languageSpanish") }
    static var languageDeutsch: String { L("languageDeutsch") }

    static func itemsCount(_ count: Int) -> String {
        String(format: L("itemsCountFormat"), count)
    }

    static var languageNames: [String] {
        [languageRussian, languageEnglish, languageFrench, languagePortugal, languageSpanish, languageDeutsch]
    }

    static func trackCount(_ count: Int) -> String {
        count == 1 ? track : tracks
    }

    static func trackLabel(count: Int) -> String {
        "► \(count) " + trackCount(count)
    }

    static func trackLabelShort(count: Int) -> String {
        "\(count) " + trackCount(count)
    }

    static func videoCountWord(_ count: Int) -> String {
        count == 1 ? video : videos
    }

    static func videoLabel(count: Int) -> String {
        "► \(count) " + videoCountWord(count)
    }

    static func videoLabelShort(count: Int) -> String {
        "\(count) " + videoCountWord(count)
    }
}
