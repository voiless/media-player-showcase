import UIKit

final class AudioTabViewController: UIViewController, TabContentControlling, AudioAlbumDetailViewControllerDelegate, UIGestureRecognizerDelegate {

    var onPlusTapped: (() -> Void)?
    var onPlayAudio: (([MediaItem], Int) -> Void)?

    func audioAlbumDetailDidUpdate() {
        refreshContent()
    }

    private let purpleAccent = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1.0)
    private static let cardBarColor = UIColor(red: 0x18/255, green: 0x0C/255, blue: 0x28/255, alpha: 1)
    private static let cardCornerRadius: CGFloat = 5
    private static let albumCardWidth: CGFloat = 158
    private static let albumCardHeight: CGFloat = 135
    private static let albumBarHeight: CGFloat = 38
    private static let cardBarColorTemplate = UIColor(red: 0x18/255, green: 0x0C/255, blue: 0x28/255, alpha: 0.65)
    private static let rowSpacing: CGFloat = 16
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
        let n = Int((availableWidth + Self.rowSpacing) / (Self.albumCardWidth + Self.rowSpacing))
        return max(1, n)
    }

    private func rowWidthForColumns(_ cols: Int) -> CGFloat {
        CGFloat(cols) * Self.albumCardWidth + CGFloat(max(0, cols - 1)) * Self.rowSpacing
    }

    private let backgroundImageView: UIImageView = {
        let v = UIImageView()
        v.image = UIImage(named: "load_back")
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let segmentTitles = [
        AppStrings.songs,
        AppStrings.album,
        AppStrings.artists,
        AppStrings.recent
    ]
    private var selectedSegmentIndex = 0

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = AppStrings.nameApp
        l.font = AppFonts.bold(22)
        l.textColor = .white
        l.fitTextWithinBounds(multiline: true)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let searchButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        b.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: config), for: .normal)
        b.tintColor = .white
        return b
    }()

    private let searchBarContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private lazy var searchBar: UISearchBar = {
        let b = UISearchBar()
        b.searchBarStyle = .minimal
        b.placeholder = AppStrings.search
        b.delegate = self
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = .clear
        return b
    }()

    private var segmentUnderline: UIView?
    private var segmentUnderlineCenterX: NSLayoutConstraint?
    private var segmentStackLeadingConstraint: NSLayoutConstraint?
    private var segmentStackTrailingConstraint: NSLayoutConstraint?
    private var segmentLineLeadingConstraint: NSLayoutConstraint?
    private var segmentLineTrailingConstraint: NSLayoutConstraint?
    private var searchBarContainerHeightConstraint: NSLayoutConstraint?

    private lazy var searchDismissTap: UITapGestureRecognizer = {
        let g = UITapGestureRecognizer(target: self, action: #selector(searchDismissBackgroundTapped))
        g.cancelsTouchesInView = false
        g.delegate = self
        g.isEnabled = false
        return g
    }()

    private let segmentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.distribution = .fillEqually
        s.spacing = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let segmentLine: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let folderImageView: UIImageView = {
        let v = UIImageView()
        v.image = UIImage(named: "empty_folder")
        v.contentMode = .scaleAspectFit
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let emptyTitleLabel: UILabel = {
        let l = UILabel()
        l.text = AppStrings.thereAreNoFilesAvailable
        l.font = AppFonts.bold(18)
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 0
        l.fitTextWithinBounds(multiline: true)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let emptySubtitleLabel: UILabel = {
        let l = UILabel()
        l.text = AppStrings.clickPlusToCreateAndOrganize
        l.font = AppFonts.regular(14)
        l.textColor = UIColor.white.withAlphaComponent(0.6)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.fitTextWithinBounds(multiline: true)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let contentContainerView: UIView = {
        let v = UIView()
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

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.showsVerticalScrollIndicator = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let gridStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 16
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let gridContentWrapper: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var audioItems: [MediaItem] = []
    private var currentAudioItems: [MediaItem] = []
    private var artistNames: [String] = []
    private var searchQuery: String = ""
    private var filteredItems: [MediaItem] {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return audioItems }
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        return audioItems.filter {
            $0.title.lowercased().contains(q) || ($0.author?.lowercased().contains(q) ?? false)
        }
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .black
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(backgroundImageView)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        view.addSubview(titleLabel)
        view.addSubview(searchButton)
        view.addSubview(segmentStack)
        view.addSubview(segmentLine)
        view.addSubview(searchBarContainer)
        searchBarContainer.addSubview(searchBar)
        view.addSubview(contentContainerView)
        contentContainerView.addSubview(folderImageView)
        contentContainerView.addSubview(emptyTitleLabel)
        contentContainerView.addSubview(emptySubtitleLabel)
        contentContainerView.addSubview(tableView)
        contentContainerView.addSubview(scrollView)
        scrollView.addSubview(gridContentWrapper)
        gridContentWrapper.addSubview(gridStack)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AudioTrackCell.self, forCellReuseIdentifier: AudioTrackCell.reuseId)
        tableView.contentInset = UIEdgeInsets(top: AudioTrackListLayout.current().topInsetFromTabs, left: 0, bottom: 0, right: 0)
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)

        for (idx, title) in segmentTitles.enumerated() {
            let btn = TouchTargetButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.fitTitleWithinBounds(maxLines: 2)
            btn.tag = idx
            btn.addTarget(self, action: #selector(segmentTapped(_:)), for: .touchUpInside)
            updateSegmentButton(btn, selected: idx == selectedSegmentIndex)
            segmentStack.addArrangedSubview(btn)
        }

        let underline = GradientLineView()
        underline.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(underline)
        segmentUnderline = underline
        segmentUnderlineCenterX = underline.centerXAnchor.constraint(equalTo: (segmentStack.arrangedSubviews[0] as! UIButton).centerXAnchor)
        NSLayoutConstraint.activate([
            underline.topAnchor.constraint(equalTo: segmentStack.bottomAnchor),
            underline.heightAnchor.constraint(equalToConstant: 2),
            underline.widthAnchor.constraint(equalTo: segmentStack.widthAnchor, multiplier: 1.0 / CGFloat(segmentTitles.count)),
            segmentUnderlineCenterX!
        ])

        searchBarContainerHeightConstraint = searchBarContainer.heightAnchor.constraint(equalToConstant: 0)
        searchBarContainerHeightConstraint?.isActive = true
        let panelInset = AppConfig.panelHorizontalInset()
        segmentStackLeadingConstraint = segmentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: panelInset)
        segmentStackTrailingConstraint = view.trailingAnchor.constraint(equalTo: segmentStack.trailingAnchor, constant: panelInset)
        segmentLineLeadingConstraint = segmentLine.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: panelInset)
        segmentLineTrailingConstraint = view.trailingAnchor.constraint(equalTo: segmentLine.trailingAnchor, constant: panelInset)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: searchBarContainer.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchBarContainer.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: searchBarContainer.trailingAnchor),
            searchBar.bottomAnchor.constraint(equalTo: searchBarContainer.bottomAnchor)
        ])

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            searchButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            searchButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 44),
            searchButton.heightAnchor.constraint(equalToConstant: 44),
            segmentStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            segmentStackLeadingConstraint!,
            segmentStackTrailingConstraint!,
            segmentStack.heightAnchor.constraint(equalToConstant: 44),
            segmentLine.topAnchor.constraint(equalTo: segmentStack.bottomAnchor),
            segmentLineLeadingConstraint!,
            segmentLineTrailingConstraint!,
            segmentLine.heightAnchor.constraint(equalToConstant: 1),
            searchBarContainer.topAnchor.constraint(equalTo: segmentLine.bottomAnchor),
            searchBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainerView.topAnchor.constraint(equalTo: searchBarContainer.bottomAnchor),
            contentContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            folderImageView.centerXAnchor.constraint(equalTo: contentContainerView.centerXAnchor),
            folderImageView.centerYAnchor.constraint(equalTo: contentContainerView.centerYAnchor, constant: -40),
            folderImageView.widthAnchor.constraint(equalToConstant: 100),
            folderImageView.heightAnchor.constraint(equalToConstant: 100),
            emptyTitleLabel.topAnchor.constraint(equalTo: folderImageView.bottomAnchor, constant: 24),
            emptyTitleLabel.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 24),
            emptyTitleLabel.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -24),
            emptySubtitleLabel.topAnchor.constraint(equalTo: emptyTitleLabel.bottomAnchor, constant: 8),
            emptySubtitleLabel.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 24),
            emptySubtitleLabel.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor, constant: -24),
            tableView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor),
            scrollView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor),
            gridContentWrapper.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            gridContentWrapper.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            gridContentWrapper.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            gridContentWrapper.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            gridContentWrapper.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            gridStack.topAnchor.constraint(equalTo: gridContentWrapper.topAnchor, constant: 20),
            gridStack.centerXAnchor.constraint(equalTo: gridContentWrapper.centerXAnchor),
            gridStack.bottomAnchor.constraint(equalTo: gridContentWrapper.bottomAnchor)
        ])
        tableView.isHidden = true
        scrollView.isHidden = true
        tableView.register(ArtistNameCell.self, forCellReuseIdentifier: ArtistNameCell.reuseId)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaCoversDidUpdate), name: MediaStorageService.mediaCoversDidUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaCoversDidUpdate), name: MediaStorageService.mediaListDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackItemOrStateDidChange), name: PlayerService.playbackItemOrStateDidChangeNotification, object: nil)
        view.addGestureRecognizer(searchDismissTap)
    }

    @objc private func playbackItemOrStateDidChange() {
        refreshContent()
    }

    @objc private func mediaCoversDidUpdate() {
        refreshContent()
    }

    @objc private func searchTapped() {
        let isShowing = !searchBarContainer.isHidden
        searchBarContainerHeightConstraint?.constant = isShowing ? 0 : 44
        searchBarContainer.isHidden = isShowing
        searchDismissTap.isEnabled = !isShowing
        if !isShowing {
            searchBar.becomeFirstResponder()
        } else {
            closeSearchUI()
        }
    }

    @objc private func searchDismissBackgroundTapped() {
        guard !searchBarContainer.isHidden else { return }
        closeSearchUI()
    }

    private func closeSearchUI() {
        searchBar.resignFirstResponder()
        searchBar.text = ""
        searchQuery = ""
        searchBarContainerHeightConstraint?.constant = 0
        searchBarContainer.isHidden = true
        searchDismissTap.isEnabled = false
        refreshContent()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === searchDismissTap else { return true }
        guard !searchBarContainer.isHidden else { return false }
        let p = touch.location(in: view)
        if searchBarContainer.convert(searchBarContainer.bounds, to: view).contains(p) {
            return false
        }
        return true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let inset = AppConfig.panelHorizontalInset()
        segmentStackLeadingConstraint?.constant = inset
        segmentStackTrailingConstraint?.constant = inset
        segmentLineLeadingConstraint?.constant = inset
        segmentLineTrailingConstraint?.constant = inset
        updateTableViewContentInsetForCurrentSegment()
        let w = scrollView.bounds.width
        if w > 0, w != lastLayoutWidth {
            lastLayoutWidth = w
            refreshContent()
        }
    }

    private func updateTableViewContentInsetForCurrentSegment() {
        let top: CGFloat
        if selectedSegmentIndex == 2 {
            top = ArtistsListLayout.topInsetFromTabs
        } else {
            top = AudioTrackListLayout.current().topInsetFromTabs
        }
        tableView.contentInset = UIEdgeInsets(top: top, left: 0, bottom: 0, right: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshContent()
    }

    private func refreshContent() {
        audioItems = MediaStorageService.shared.loadAudioItems()
        switch selectedSegmentIndex {
            case 0:
            currentAudioItems = filteredItems
            if filteredItems.isEmpty {
                folderImageView.isHidden = false
                emptyTitleLabel.isHidden = false
                emptySubtitleLabel.isHidden = false
                emptyTitleLabel.text = AppStrings.thereAreNoFilesAvailable
                emptySubtitleLabel.text = AppStrings.clickPlusToCreateAndOrganize
                tableView.isHidden = true
                scrollView.isHidden = true
            } else {
                folderImageView.isHidden = true
                emptyTitleLabel.isHidden = true
                emptySubtitleLabel.isHidden = true
                tableView.isHidden = false
                scrollView.isHidden = true
                tableView.reloadData()
            }
        case 1:
            folderImageView.isHidden = true
            emptyTitleLabel.isHidden = true
            emptySubtitleLabel.isHidden = true
            tableView.isHidden = true
            scrollView.isHidden = false
            buildAlbumGrid(albums: MediaStorageService.shared.loadAudioAlbums())
        case 2:
            let authors = Set(audioItems.compactMap { $0.author }.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
            artistNames = authors.sorted()
            currentAudioItems = []
            if artistNames.isEmpty {
                folderImageView.isHidden = false
                emptyTitleLabel.isHidden = false
                emptySubtitleLabel.isHidden = false
                emptyTitleLabel.text = AppStrings.noArtists
                emptySubtitleLabel.text = ""
                tableView.isHidden = true
                scrollView.isHidden = true
            } else {
                folderImageView.isHidden = true
                emptyTitleLabel.isHidden = true
                emptySubtitleLabel.isHidden = true
                tableView.isHidden = false
                scrollView.isHidden = true
                tableView.reloadData()
            }
        case 3:
            let recentIds = MediaStorageService.shared.loadRecentAudioIds()
            currentAudioItems = recentIds.compactMap { MediaStorageService.shared.mediaItem(byId: $0) }
            if currentAudioItems.isEmpty {
                folderImageView.isHidden = false
                emptyTitleLabel.isHidden = false
                emptySubtitleLabel.isHidden = false
                emptyTitleLabel.text = AppStrings.thereAreNoFilesAvailable
                emptySubtitleLabel.text = AppStrings.clickPlusToCreateAndOrganize
                tableView.isHidden = true
                scrollView.isHidden = true
            } else {
                folderImageView.isHidden = true
                emptyTitleLabel.isHidden = true
                emptySubtitleLabel.isHidden = true
                tableView.isHidden = false
                scrollView.isHidden = true
                tableView.reloadData()
            }
        default:
            tableView.isHidden = true
            scrollView.isHidden = true
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

    private func buildAlbumGrid(albums: [Album]) {
        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let cols = numberOfColumns()
        gridStackWidthConstraint?.isActive = false
        gridStackWidthConstraint = gridStack.widthAnchor.constraint(equalToConstant: rowWidthForColumns(cols))
        gridStackWidthConstraint?.isActive = true
        let newCard = makeNewAudioAlbumCard()
        let tapNew = UITapGestureRecognizer(target: self, action: #selector(newAudioAlbumTapped))
        newCard.addGestureRecognizer(tapNew)
        newCard.isUserInteractionEnabled = true
        var rowStack = makeRowStack()
        gridStack.addArrangedSubview(rowStack)
        rowStack.addArrangedSubview(newCard)
        newCard.widthAnchor.constraint(equalToConstant: Self.albumCardWidth).isActive = true
        newCard.setContentHuggingPriority(.required, for: .horizontal)
        for (idx, album) in albums.enumerated() {
            if rowStack.arrangedSubviews.count == numberOfColumns() {
                rowStack = makeRowStack()
                gridStack.addArrangedSubview(rowStack)
            }
            let card = makeAudioAlbumCard(album: album, index: idx)
            rowStack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalToConstant: Self.albumCardWidth).isActive = true
            card.setContentHuggingPriority(.required, for: .horizontal)
        }
        while rowStack.arrangedSubviews.count < numberOfColumns() {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            rowStack.addArrangedSubview(spacer)
        }
    }

    private func makeNewAudioAlbumCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
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
        let bar = UIView()
        bar.backgroundColor = Self.cardBarColorTemplate
        bar.layer.cornerRadius = Self.cardCornerRadius
        bar.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        bar.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = AppStrings.newAlbum
        label.font = AppFonts.semibold(14)
        label.textColor = .white
        label.fitTextWithinBounds(multiline: true)
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bar)
        bar.addSubview(label)
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Self.albumCardWidth),
            card.heightAnchor.constraint(equalToConstant: Self.albumCardHeight),
            coverImageView.topAnchor.constraint(equalTo: card.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalToConstant: Self.albumCardHeight - Self.albumBarHeight),
            buttonLight.centerXAnchor.constraint(equalTo: coverImageView.centerXAnchor),
            buttonLight.centerYAnchor.constraint(equalTo: coverImageView.centerYAnchor),
            buttonLight.widthAnchor.constraint(equalToConstant: 34),
            buttonLight.heightAnchor.constraint(equalToConstant: 34),
            bar.topAnchor.constraint(equalTo: coverImageView.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            label.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ])
        return card
    }

    private func makeAudioAlbumCard(album: Album, index: Int) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        card.layer.cornerRadius = Self.cardCornerRadius
        card.clipsToBounds = true
        card.accessibilityIdentifier = album.id
        let coverImageView = UIImageView(image: DefaultCover.playlistFolderCover155x135)
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.layer.cornerRadius = Self.cardCornerRadius
        coverImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        let bar = UIView()
        bar.backgroundColor = Self.cardBarColor
        bar.layer.cornerRadius = Self.cardCornerRadius
        bar.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        bar.translatesAutoresizingMaskIntoConstraints = false
        let titleLabel = UILabel()
        titleLabel.text = album.name
        titleLabel.font = AppFonts.semibold(14)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.fitTextWithinBounds(multiline: false)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let n = album.itemIds.count
        let trackLabel = UILabel()
        trackLabel.text = AppStrings.trackLabelShort(count: n)
        trackLabel.font = AppFonts.regular(12)
        trackLabel.textColor = UIColor(white: 0.65, alpha: 1)
        trackLabel.fitTextWithinBounds(multiline: false)
        trackLabel.translatesAutoresizingMaskIntoConstraints = false
        let playIcon = UIImageView(image: UIImage(systemName: "play.fill"))
        playIcon.tintColor = purpleAccent
        playIcon.contentMode = .scaleAspectFit
        playIcon.translatesAutoresizingMaskIntoConstraints = false
        let menuBtn = TouchTargetButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        menuBtn.setImage(UIImage(systemName: "ellipsis", withConfiguration: config), for: .normal)
        menuBtn.tintColor = .white
        menuBtn.tag = index
        menuBtn.addTarget(self, action: #selector(audioAlbumMenuTapped(_:)), for: .touchUpInside)
        menuBtn.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(coverImageView)
        card.addSubview(bar)
        bar.addSubview(titleLabel)
        bar.addSubview(playIcon)
        bar.addSubview(trackLabel)
        bar.addSubview(menuBtn)
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Self.albumCardWidth),
            card.heightAnchor.constraint(equalToConstant: Self.albumCardHeight),
            coverImageView.topAnchor.constraint(equalTo: card.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalToConstant: Self.albumCardHeight - Self.albumBarHeight),
            bar.topAnchor.constraint(equalTo: coverImageView.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: bar.topAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: menuBtn.leadingAnchor, constant: -8),
            playIcon.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            playIcon.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            playIcon.widthAnchor.constraint(equalToConstant: 10),
            playIcon.heightAnchor.constraint(equalToConstant: 10),
            trackLabel.leadingAnchor.constraint(equalTo: playIcon.trailingAnchor, constant: 4),
            trackLabel.centerYAnchor.constraint(equalTo: playIcon.centerYAnchor),
            menuBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            menuBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            menuBtn.widthAnchor.constraint(equalToConstant: 44),
            menuBtn.heightAnchor.constraint(equalToConstant: 44)
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(audioAlbumCardTapped(_:)))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true
        return card
    }

    @objc private func newAudioAlbumTapped() {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.newPlaylist
        vc.messageText = AppStrings.chooseTitleForNewPlaylist
        vc.placeholder = AppStrings.placeholder
        vc.onSave = { [weak self] name in
            var albums = MediaStorageService.shared.loadAudioAlbums()
            albums.append(Album(id: UUID().uuidString, name: name, itemIds: []))
            MediaStorageService.shared.saveAudioAlbums(albums)
            self?.refreshContent()
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    @objc private func audioAlbumCardTapped(_ g: UITapGestureRecognizer) {
        guard let id = g.view?.accessibilityIdentifier else { return }
        let albums = MediaStorageService.shared.loadAudioAlbums()
        guard let album = albums.first(where: { $0.id == id }) else { return }
        openAudioAlbum(album)
    }

    private func openAudioAlbum(_ album: Album) {
        let detail = AudioAlbumDetailViewController(album: album)
        detail.delegate = self
        detail.onPlayAudio = onPlayAudio
        navigationController?.pushViewController(detail, animated: true)
    }

    @objc private func audioAlbumMenuTapped(_ sender: UIButton) {
        let albums = MediaStorageService.shared.loadAudioAlbums()
        let idx = sender.tag
        guard idx >= 0 && idx < albums.count else { return }
        let album = albums[idx]
        let sheet = DarkActionSheetViewController()
sheet.titleText = AppStrings.selectionOfChanges
            sheet.actions = [
            (AppStrings.rename, .default, { [weak self] in self?.showRenameAudioAlbum(album: album) }),
            (AppStrings.delete, .destructive, { [weak self] in self?.showDeleteAudioAlbum(album: album) })
        ]
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle = .crossDissolve
        present(sheet, animated: true)
    }

    private func showRenameAudioAlbum(album: Album) {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.rename
        vc.initialText = album.name
        vc.onSave = { [weak self] name in
            var albums = MediaStorageService.shared.loadAudioAlbums()
            guard let i = albums.firstIndex(where: { $0.id == album.id }) else { return }
            albums[i].name = name
            MediaStorageService.shared.saveAudioAlbums(albums)
            self?.refreshContent()
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func showDeleteAudioAlbum(album: Album) {
        let vc = DarkConfirmViewController()
        vc.titleText = AppStrings.areYouSure
        vc.messageText = AppStrings.confirmFileDeletion
        vc.onDelete = { [weak self] in
            var albums = MediaStorageService.shared.loadAudioAlbums()
            albums.removeAll { $0.id == album.id }
            MediaStorageService.shared.saveAudioAlbums(albums)
            self?.refreshContent()
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private static let segmentGradientTag = 19999

    private func updateSegmentButton(_ btn: UIButton, selected: Bool) {
        let title = segmentTitles[btn.tag]
        let font = selected ? AppFonts.bold(14) : AppFonts.regular(14)
        btn.subviews.first { $0.tag == Self.segmentGradientTag }?.removeFromSuperview()
        btn.setImage(nil, for: .normal)
        if selected {
            btn.setTitle(nil, for: .normal)
            let gradientView = SegmentGradientTextView()
            gradientView.tag = Self.segmentGradientTag
            gradientView.setTitle(title, font: font)
            gradientView.translatesAutoresizingMaskIntoConstraints = false
            btn.addSubview(gradientView)
            NSLayoutConstraint.activate([
                gradientView.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
                gradientView.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
                gradientView.leadingAnchor.constraint(greaterThanOrEqualTo: btn.leadingAnchor, constant: 4),
                gradientView.trailingAnchor.constraint(lessThanOrEqualTo: btn.trailingAnchor, constant: -4)
            ])
        } else {
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(AppColors.segmentInactive, for: .normal)
            btn.titleLabel?.font = font
            btn.fitTitleWithinBounds(maxLines: 2)
        }
    }

    @objc private func segmentTapped(_ sender: UIButton) {
        selectedSegmentIndex = sender.tag
        for (idx, subview) in segmentStack.arrangedSubviews.enumerated() {
            guard let btn = subview as? UIButton else { continue }
            updateSegmentButton(btn, selected: idx == selectedSegmentIndex)
        }
        guard let underline = segmentUnderline, selectedSegmentIndex < segmentStack.arrangedSubviews.count else { return }
        segmentUnderlineCenterX?.isActive = false
        segmentUnderlineCenterX = underline.centerXAnchor.constraint(equalTo: segmentStack.arrangedSubviews[selectedSegmentIndex].centerXAnchor)
        segmentUnderlineCenterX?.isActive = true
        view.layoutIfNeeded()
        refreshContent()
        updateTableViewContentInsetForCurrentSegment()
    }
}

extension AudioTabViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchQuery = searchText
        refreshContent()
    }
}

private enum ArtistsListLayout {
    static let topInsetFromTabs: CGFloat = 12
    static let rowHeight: CGFloat = 48
}

private struct AudioTrackListLayout {
    let trackContentHeight: CGFloat
    let spacingBetweenTracks: CGFloat
    let thumbSize: CGFloat
    let titleTopInsetWithMetadata: CGFloat
    let subtitleBottomInsetWithMetadata: CGFloat
    let topInsetFromTabs: CGFloat
    let horizontalInset: CGFloat

    var contentHeight: CGFloat { trackContentHeight + spacingBetweenTracks }
    var trackRowHeight: CGFloat { contentHeight }

    static func current() -> AudioTrackListLayout {
        let screenHeight = UIScreen.main.bounds.height
        let refMin: CGFloat = 667
        let refMax: CGFloat = 932
        let t = min(1, max(0, (screenHeight - refMin) / (refMax - refMin)))
        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
        return AudioTrackListLayout(
            trackContentHeight: lerp(44, 60),
            spacingBetweenTracks: lerp(12, 24),
            thumbSize: lerp(44, 60),
            titleTopInsetWithMetadata: lerp(3, 5),
            subtitleBottomInsetWithMetadata: lerp(3, 5),
            topInsetFromTabs: lerp(12, 24),
            horizontalInset: lerp(12, 16)
        )
    }
}

extension AudioTabViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if selectedSegmentIndex == 2 {
            return ArtistsListLayout.rowHeight
        }
        return AudioTrackListLayout.current().trackContentHeight
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        if selectedSegmentIndex == 2 { return 1 }
        if selectedSegmentIndex == 0 { return filteredItems.count }
        if selectedSegmentIndex == 3 { return currentAudioItems.count }
        return 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if selectedSegmentIndex == 2 { return artistNames.count }
        return 1
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if selectedSegmentIndex == 2 { return 0 }
        return AudioTrackListLayout.current().spacingBetweenTracks
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if selectedSegmentIndex == 2 { return nil }
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if selectedSegmentIndex == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: ArtistNameCell.reuseId, for: indexPath) as! ArtistNameCell
            cell.configure(artistName: artistNames[indexPath.row])
            return cell
        }
        let trackIndex = indexPath.section
        let item = selectedSegmentIndex == 3 ? currentAudioItems[trackIndex] : filteredItems[trackIndex]
        let cell = tableView.dequeueReusableCell(withIdentifier: AudioTrackCell.reuseId, for: indexPath) as! AudioTrackCell
        cell.configure(item: item)
        cell.applyLayout(AudioTrackListLayout.current())
        cell.onMenuTapped = { [weak self] in self?.showAudioMenu(item: item) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if selectedSegmentIndex == 2 {
            let name = artistNames[indexPath.row]
            let detail = ArtistDetailViewController(artistName: name)
            detail.onPlayAudio = onPlayAudio
            navigationController?.pushViewController(detail, animated: true)
            return
        }
        let trackIndex = indexPath.section
        let items = selectedSegmentIndex == 3 ? currentAudioItems : filteredItems
        let item = items[trackIndex]
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        onPlayAudio?(items, idx)
    }

    private func showAudioMenu(item: MediaItem) {
        if selectedSegmentIndex == 3 {
            let sheet = DarkActionSheetViewController()
            sheet.titleText = AppStrings.selectionOfChanges
            sheet.actions = [
                (AppStrings.delete, .destructive, { [weak self] in
                    MediaStorageService.shared.removeFromRecentAudioHistory(itemId: item.id)
                    self?.refreshContent()
                })
            ]
            sheet.modalPresentationStyle = .overFullScreen
            sheet.modalTransitionStyle = .crossDissolve
            present(sheet, animated: true)
            return
        }
        let sheet = DarkActionSheetViewController()
            sheet.titleText = AppStrings.selectionOfChanges
            sheet.actions = [
                (AppStrings.rename, .default, { [weak self] in self?.showRenameAudio(item: item) }),
                (AppStrings.delete, .destructive, { [weak self] in self?.showDeleteAudio(item: item) })
            ]
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle = .crossDissolve
        present(sheet, animated: true)
    }

    private func showRenameAudio(item: MediaItem) {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.rename
        vc.initialText = item.title
        vc.onSave = { [weak self] name in
            var items = MediaStorageService.shared.loadAudioItems()
            guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[idx].title = name
            MediaStorageService.shared.saveAudioItems(items)
            MediaStorageService.shared.clearLastPlayback(itemId: item.id)
            self?.refreshContent()
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func showDeleteAudio(item: MediaItem) {
        let vc = DarkConfirmViewController()
        vc.titleText = AppStrings.areYouSure
        vc.messageText = AppStrings.confirmFileDeletion
        vc.onDelete = { [weak self] in
            MediaStorageService.shared.removeAudioItem(id: item.id)
            PlayerService.shared.handleAudioItemRemoved(id: item.id)
            self?.refreshContent()
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }
}

private final class AudioTrackCell: UITableViewCell {
    static let reuseId = "AudioTrackCell"
    private static let subtitleMinimumHeight: CGFloat = 12
    private static let innerPadding: CGFloat = 12
    private static let trackContainerCornerRadius: CGFloat = 10
    var onMenuTapped: (() -> Void)?

    private var titleTopConstraint: NSLayoutConstraint?
    private var titleCenterYConstraint: NSLayoutConstraint?
    private var subtitleTopConstraint: NSLayoutConstraint?
    private var subtitleBottomConstraint: NSLayoutConstraint?
    private var thumbWidthConstraint: NSLayoutConstraint?
    private var thumbHeightConstraint: NSLayoutConstraint?
    private var contentHeightConstraint: NSLayoutConstraint?
    private var leadingInsetConstraint: NSLayoutConstraint?
    private var trailingInsetConstraint: NSLayoutConstraint?

    private let trackContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.layer.cornerRadius = AudioTrackCell.trackContainerCornerRadius
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let thumbView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.layer.cornerRadius = AppColors.cardCornerRadius
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let playingWaveContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var waveBars: [UIView] = []

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFonts.semibold(14)
        l.textColor = .white
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        l.adjustsFontSizeToFitWidth = false
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFonts.regular(12)
        l.textColor = UIColor.white.withAlphaComponent(0.7)
        l.fitTextWithinBounds(multiline: true)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let menuButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        b.setImage(UIImage(systemName: "ellipsis", withConfiguration: config), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(trackContainerView)
        trackContainerView.addSubview(thumbView)
        trackContainerView.addSubview(playingWaveContainer)
        trackContainerView.addSubview(titleLabel)
        trackContainerView.addSubview(subtitleLabel)
        trackContainerView.addSubview(menuButton)
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)

        let layout = AudioTrackListLayout.current()
        let top = titleLabel.topAnchor.constraint(equalTo: thumbView.topAnchor, constant: layout.titleTopInsetWithMetadata)
        let centerY = titleLabel.centerYAnchor.constraint(equalTo: thumbView.centerYAnchor)
        let subTop = subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1)
        let subBottom = subtitleLabel.bottomAnchor.constraint(equalTo: thumbView.bottomAnchor, constant: -layout.subtitleBottomInsetWithMetadata)
        titleTopConstraint = top
        titleCenterYConstraint = centerY
        subtitleTopConstraint = subTop
        subtitleBottomConstraint = subBottom

        let tw = thumbView.widthAnchor.constraint(equalToConstant: layout.thumbSize)
        let th = thumbView.heightAnchor.constraint(equalToConstant: layout.thumbSize)
        let ch = contentView.heightAnchor.constraint(equalToConstant: layout.trackContentHeight)
        thumbWidthConstraint = tw
        thumbHeightConstraint = th
        contentHeightConstraint = ch
        let leadingInset = trackContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: layout.horizontalInset)
        let trailingInset = contentView.trailingAnchor.constraint(equalTo: trackContainerView.trailingAnchor, constant: layout.horizontalInset)
        leadingInsetConstraint = leadingInset
        trailingInsetConstraint = trailingInset

        NSLayoutConstraint.activate([
            trackContainerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            trackContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            leadingInset,
            trailingInset,
            thumbView.leadingAnchor.constraint(equalTo: trackContainerView.leadingAnchor, constant: Self.innerPadding),
            thumbView.topAnchor.constraint(equalTo: trackContainerView.topAnchor),
            thumbView.bottomAnchor.constraint(equalTo: trackContainerView.bottomAnchor),
            tw,
            th,
            titleLabel.leadingAnchor.constraint(equalTo: thumbView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8),
            top,
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8),
            subTop,
            subBottom,
            subtitleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.subtitleMinimumHeight),
            menuButton.trailingAnchor.constraint(equalTo: trackContainerView.trailingAnchor, constant: -Self.innerPadding),
            menuButton.centerYAnchor.constraint(equalTo: thumbView.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 40),
            menuButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        playingWaveContainer.leadingAnchor.constraint(equalTo: thumbView.leadingAnchor).isActive = true
        playingWaveContainer.trailingAnchor.constraint(equalTo: thumbView.trailingAnchor).isActive = true
        playingWaveContainer.topAnchor.constraint(equalTo: thumbView.topAnchor).isActive = true
        playingWaveContainer.bottomAnchor.constraint(equalTo: thumbView.bottomAnchor).isActive = true
        playingWaveContainer.layer.cornerRadius = AppColors.cardCornerRadius
        playingWaveContainer.clipsToBounds = true
        setupWaveBars()
        ch.isActive = true
    }

    private func setupWaveBars() {
        let barCount = 5
        let barW: CGFloat = 3
        let barHeight: CGFloat = 14
        let spacing: CGFloat = 3
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = spacing
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        playingWaveContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: playingWaveContainer.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: playingWaveContainer.centerYAnchor),
            stack.heightAnchor.constraint(equalToConstant: barHeight)
        ])
        for _ in 0..<barCount {
            let bar = UIView()
            bar.backgroundColor = .white
            bar.layer.cornerRadius = 1.5
            bar.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(bar)
            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: barW),
                bar.heightAnchor.constraint(equalToConstant: barHeight)
            ])
            waveBars.append(bar)
        }
    }

    private func startWaveAnimation() {
        stopWaveAnimation()
        let duration: CFTimeInterval = 0.4
        for (i, bar) in waveBars.enumerated() {
            let anim = CABasicAnimation(keyPath: "transform.scale.y")
            anim.fromValue = 0.35
            anim.toValue = 1.0
            anim.duration = duration
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timeOffset = Double(i) * duration / Double(waveBars.count)
            bar.layer.add(anim, forKey: "wave")
        }
    }

    private func stopWaveAnimation() {
        waveBars.forEach { $0.layer.removeAllAnimations() }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
    }

    required init?(coder: NSCoder) { nil }

    func configure(item: MediaItem) {
        titleLabel.text = item.displayTitle
        let hasMetadata = (item.author?.isEmpty == false)
        subtitleLabel.text = item.author ?? ""
        subtitleLabel.isHidden = !hasMetadata

        titleTopConstraint?.isActive = hasMetadata
        titleCenterYConstraint?.isActive = !hasMetadata
        subtitleTopConstraint?.isActive = hasMetadata
        subtitleBottomConstraint?.isActive = hasMetadata

        thumbView.image = item.coverImageURL.flatMap { UIImage(contentsOfFile: $0.path) } ?? DefaultCover.audioBackground
        let isPlaying = PlayerService.shared.currentMediaItem?.id == item.id && PlayerService.shared.isPlaying
        playingWaveContainer.isHidden = !isPlaying
        if isPlaying {
            startWaveAnimation()
        } else {
            stopWaveAnimation()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopWaveAnimation()
        playingWaveContainer.isHidden = true
    }

    func applyLayout(_ layout: AudioTrackListLayout) {
        thumbWidthConstraint?.constant = layout.thumbSize
        thumbHeightConstraint?.constant = layout.thumbSize
        contentHeightConstraint?.constant = layout.trackContentHeight
        leadingInsetConstraint?.constant = layout.horizontalInset
        trailingInsetConstraint?.constant = layout.horizontalInset
        titleTopConstraint?.constant = layout.titleTopInsetWithMetadata
        subtitleBottomConstraint?.constant = -layout.subtitleBottomInsetWithMetadata
    }

    @objc private func menuTapped() { onMenuTapped?() }
}

private final class ArtistNameCell: UITableViewCell {
    static let reuseId = "ArtistNameCell"
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFonts.semibold(16)
        l.textColor = .white
        l.fitTextWithinBounds(multiline: true)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    required init?(coder: NSCoder) { nil }
    func configure(artistName: String) {
        titleLabel.text = artistName
    }
}

