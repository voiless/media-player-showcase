import UIKit

final class VideoTabViewController: UIViewController, TabContentControlling, AlbumDetailViewControllerDelegate, FolderDetailViewControllerDelegate {

    func albumDetailDidUpdate() {
        refreshContent()
    }

    func folderDetailDidUpdate() {
        refreshContent()
    }

    private func openFolder(_ folder: MediaFolder) {
        let detail = FolderDetailViewController(folder: folder)
        detail.delegate = self
        detail.onPlayVideo = onPlayVideo
        navigationController?.pushViewController(detail, animated: true)
    }

    var onPlusTapped: (() -> Void)?
    var onPlayVideo: (([MediaItem], Int) -> Void)?

    private let purpleAccent = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1.0)

    private let backgroundImageView: UIImageView = {
        let v = UIImageView()
        v.image = UIImage(named: "load_back")
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let segmentTitles = [
        AppStrings.video,
        AppStrings.album,
        AppStrings.folder,
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

    private let getProButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.layer.cornerRadius = 18
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private var getProGradientLayer: CAGradientLayer?
    private var segmentUnderline: UIView?
    private var segmentUnderlineCenterX: NSLayoutConstraint?
    private var segmentStackLeadingConstraint: NSLayoutConstraint?
    private var segmentStackTrailingConstraint: NSLayoutConstraint?
    private var segmentLineLeadingConstraint: NSLayoutConstraint?
    private var segmentLineTrailingConstraint: NSLayoutConstraint?

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

    private static let rowSpacing: CGFloat = 16
    private static let horizontalInset: CGFloat = 20
    private var gridStackWidthConstraint: NSLayoutConstraint?
    private var lastLayoutWidth: CGFloat = 0

    private func availableWidthForGrid(containerWidth: CGFloat? = nil) -> CGFloat {
        let w = containerWidth ?? (scrollView.bounds.width > 0 ? scrollView.bounds.width : contentContainerView.bounds.width)
        return max(0, w - Self.horizontalInset * 2)
    }

    private func numberOfColumns(containerWidth: CGFloat? = nil) -> Int {
        let availableWidth = availableWidthForGrid(containerWidth: containerWidth)
        guard availableWidth > 0 else { return 2 }
        let n = Int((availableWidth + Self.rowSpacing) / (Self.videoCardWidth + Self.rowSpacing))
        return max(1, n)
    }

    private func rowWidthForColumns(_ cols: Int) -> CGFloat {
        CGFloat(cols) * Self.videoCardWidth + CGFloat(max(0, cols - 1)) * Self.rowSpacing
    }

    private func gridRowHorizontalInset(containerWidth: CGFloat) -> CGFloat {
        let cols = numberOfColumns(containerWidth: containerWidth)
        let cardAlignedInset = max(AppConfig.panelHorizontalInset(), (containerWidth - rowWidthForColumns(cols)) / 2)
        return AppConfig.adaptiveValue(from: cardAlignedInset, to: 24)
    }

    private static let videoCardWidth: CGFloat = 158
    private static let videoCardHeight: CGFloat = 135
    private static let cardCornerRadius: CGFloat = 5
    private static let videoBarHeight: CGFloat = 38
    private var currentVideoItems: [MediaItem] = []

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
        view.addSubview(segmentStack)
        view.addSubview(segmentLine)
        view.addSubview(contentContainerView)
        contentContainerView.addSubview(folderImageView)
        contentContainerView.addSubview(emptyTitleLabel)
        contentContainerView.addSubview(emptySubtitleLabel)
        contentContainerView.addSubview(scrollView)
        scrollView.addSubview(gridContentWrapper)
        gridContentWrapper.addSubview(gridStack)

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

        NotificationCenter.default.addObserver(self, selector: #selector(mediaCoversDidUpdate), name: MediaStorageService.mediaCoversDidUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaCoversDidUpdate), name: MediaStorageService.mediaListDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pipConversionProgressDidUpdate), name: MediaStorageService.pipConversionProgressNotification, object: nil)

        let panelInset = gridRowHorizontalInset(containerWidth: UIScreen.main.bounds.width)
        segmentStackLeadingConstraint = segmentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: panelInset)
        segmentStackTrailingConstraint = view.trailingAnchor.constraint(equalTo: segmentStack.trailingAnchor, constant: panelInset)
        segmentLineLeadingConstraint = segmentLine.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: panelInset)
        segmentLineTrailingConstraint = view.trailingAnchor.constraint(equalTo: segmentLine.trailingAnchor, constant: panelInset)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            segmentStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            segmentStackLeadingConstraint!,
            segmentStackTrailingConstraint!,
            segmentStack.heightAnchor.constraint(equalToConstant: 44),
            segmentLine.topAnchor.constraint(equalTo: segmentStack.bottomAnchor),
            segmentLineLeadingConstraint!,
            segmentLineTrailingConstraint!,
            segmentLine.heightAnchor.constraint(equalToConstant: 1),
            contentContainerView.topAnchor.constraint(equalTo: segmentLine.bottomAnchor),
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
        scrollView.isHidden = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let inset = gridRowHorizontalInset(containerWidth: width)
        segmentStackLeadingConstraint?.constant = inset
        segmentStackTrailingConstraint?.constant = inset
        segmentLineLeadingConstraint?.constant = inset
        segmentLineTrailingConstraint?.constant = inset
        let w = scrollView.bounds.width
        if w > 0, w != lastLayoutWidth {
            lastLayoutWidth = w
            refreshContent()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        gridContentWrapper.setNeedsLayout()
        gridContentWrapper.layoutIfNeeded()
    }

    private func filterVideos(_ items: [MediaItem]) -> [MediaItem] {
        return items
    }

    private func filterAlbums(_ albums: [Album]) -> [Album] {
        return albums
    }

    private func filterFolders(_ folders: [MediaFolder]) -> [MediaFolder] {
        return folders
    }

    @objc private func mediaCoversDidUpdate() {
        refreshContent()
    }

    @objc private func pipConversionProgressDidUpdate() {
        guard selectedSegmentIndex == 0 || selectedSegmentIndex == 3 else { return }
        refreshContent()
    }

    private func refreshContent() {
        let isEmpty: Bool
        switch selectedSegmentIndex {
        case 0:
            let items = filterVideos(MediaStorageService.shared.loadVideoItems())
            currentVideoItems = items
            isEmpty = items.isEmpty
            if !isEmpty {
                buildVideoGrid(items: items)
            }
        case 1:
            let albums = filterAlbums(MediaStorageService.shared.loadAlbums())
            isEmpty = false
            buildAlbumGrid(albums: albums)
        case 2:
            let folders = filterFolders(MediaStorageService.shared.loadFolders())
            isEmpty = false
            buildFolderGrid(folders: folders)
        case 3:
            let recentIds = MediaStorageService.shared.loadRecentVideoIds()
            let items = filterVideos(recentIds.compactMap { MediaStorageService.shared.mediaItem(byId: $0) })
            currentVideoItems = items
            isEmpty = items.isEmpty
            if !isEmpty {
                buildVideoGrid(items: items)
            }
        default:
            isEmpty = true
        }
        if selectedSegmentIndex == 1 || selectedSegmentIndex == 2 {
            folderImageView.isHidden = true
            emptyTitleLabel.isHidden = true
            emptySubtitleLabel.isHidden = true
            scrollView.isHidden = false
        } else if isEmpty {
            folderImageView.isHidden = false
            emptyTitleLabel.isHidden = false
            emptySubtitleLabel.isHidden = false
            scrollView.isHidden = true
        } else {
            folderImageView.isHidden = true
            emptyTitleLabel.isHidden = true
            emptySubtitleLabel.isHidden = true
            scrollView.isHidden = false
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

    private func buildVideoGrid(items: [MediaItem]) {
        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let cols = numberOfColumns()
        gridStackWidthConstraint?.isActive = false
        gridStackWidthConstraint = gridStack.widthAnchor.constraint(equalToConstant: rowWidthForColumns(cols))
        gridStackWidthConstraint?.isActive = true
        var rowStack: UIStackView?
        var count = 0
        for (idx, item) in items.enumerated() {
            if count == 0 {
                rowStack = makeRowStack()
                gridStack.addArrangedSubview(rowStack!)
            }
            let card = makeVideoCard(item: item, index: idx)
            rowStack!.addArrangedSubview(card)
            card.widthAnchor.constraint(equalToConstant: Self.videoCardWidth).isActive = true
            card.setContentHuggingPriority(.required, for: .horizontal)
            count += 1
            if count == numberOfColumns() { count = 0 }
        }
        if count > 0 {
            let cols = numberOfColumns()
            while count < cols {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                rowStack!.addArrangedSubview(spacer)
                count += 1
            }
        }
    }

    private static let cardBackgroundColor = UIColor(red: 0x1C/255, green: 0x0E/255, blue: 0x2A/255, alpha: 1)
    private static let cardBarColor = UIColor(red: 0x18/255, green: 0x0C/255, blue: 0x28/255, alpha: 1)

    private func makeVideoCard(item: MediaItem, index: Int) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        card.layer.cornerRadius = Self.cardCornerRadius
        card.clipsToBounds = true
        let thumb = UIImageView()
        thumb.image = item.coverImageURL.flatMap { UIImage(contentsOfFile: $0.path) } ?? DefaultCover.videoCover
        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.layer.cornerRadius = Self.cardCornerRadius
        thumb.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        thumb.backgroundColor = UIColor(white: 0.2, alpha: 1)
        thumb.translatesAutoresizingMaskIntoConstraints = false
        let bar = UIView()
        bar.backgroundColor = Self.cardBarColor
        bar.layer.cornerRadius = Self.cardCornerRadius
        bar.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        bar.translatesAutoresizingMaskIntoConstraints = false
        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = AppFonts.semibold(14)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.fitTextWithinBounds(multiline: false)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let menuBtn = TouchTargetButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        menuBtn.setImage(UIImage(systemName: "ellipsis", withConfiguration: config), for: .normal)
        menuBtn.tintColor = .white
        menuBtn.tag = index
        menuBtn.translatesAutoresizingMaskIntoConstraints = false
        menuBtn.addTarget(self, action: #selector(videoMenuTapped(_:)), for: .touchUpInside)
        card.addSubview(thumb)
        card.addSubview(bar)
        bar.addSubview(titleLabel)
        bar.addSubview(menuBtn)
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Self.videoCardWidth),
            card.heightAnchor.constraint(equalToConstant: Self.videoCardHeight),
            thumb.topAnchor.constraint(equalTo: card.topAnchor),
            thumb.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            thumb.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            thumb.heightAnchor.constraint(equalToConstant: Self.videoCardHeight - Self.videoBarHeight),
            bar.topAnchor.constraint(equalTo: thumb.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: menuBtn.leadingAnchor, constant: -8),
            menuBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            menuBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            menuBtn.widthAnchor.constraint(equalToConstant: 44),
            menuBtn.heightAnchor.constraint(equalToConstant: 44)
        ])
        addVideoProcessingOverlayIfNeeded(to: thumb, item: item)
        let tap = UITapGestureRecognizer(target: self, action: #selector(videoCardTapped(_:)))
        tap.numberOfTapsRequired = 1
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true
        card.accessibilityIdentifier = item.id
        return card
    }

    private func addVideoProcessingOverlayIfNeeded(to thumb: UIView, item: MediaItem) {
        switch item.pipPreparation {
        case .pending:
            let overlay = UIView()
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            overlay.translatesAutoresizingMaskIntoConstraints = false
            overlay.isUserInteractionEnabled = false
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = .white
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.startAnimating()
            let statusLabel = UILabel()
            statusLabel.textColor = .white
            statusLabel.font = AppFonts.regular(11)
            statusLabel.textAlignment = .center
            statusLabel.numberOfLines = 2
            statusLabel.translatesAutoresizingMaskIntoConstraints = false
            let pct = PiPConversionService.shared.progressPercent(forItemId: item.id) ?? 0
            if pct > 0 {
                statusLabel.text = AppStrings.pipPreparingProgressLabel(percent: pct)
            } else {
                statusLabel.text = AppStrings.libraryPipPreparing
            }
            let progressBar = UIProgressView(progressViewStyle: .bar)
            progressBar.translatesAutoresizingMaskIntoConstraints = false
            progressBar.trackTintColor = UIColor.white.withAlphaComponent(0.25)
            progressBar.progressTintColor = purpleAccent
            progressBar.progress = pct > 0 ? Float(pct) / 100.0 : 0
            progressBar.isHidden = pct <= 0
            thumb.addSubview(overlay)
            overlay.addSubview(spinner)
            overlay.addSubview(statusLabel)
            overlay.addSubview(progressBar)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: thumb.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: thumb.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: thumb.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: thumb.bottomAnchor),
                spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -12),
                statusLabel.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 8),
                statusLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -8),
                statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 8),
                progressBar.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 12),
                progressBar.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -12),
                progressBar.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -10),
                progressBar.heightAnchor.constraint(equalToConstant: 4)
            ])
        case .failed:
            let overlay = UIView()
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            overlay.translatesAutoresizingMaskIntoConstraints = false
            overlay.isUserInteractionEnabled = false
            let errLabel = UILabel()
            errLabel.text = AppStrings.libraryPipConversionErrorShort
            errLabel.textColor = .white
            errLabel.font = AppFonts.regular(11)
            errLabel.textAlignment = .center
            errLabel.numberOfLines = 3
            errLabel.translatesAutoresizingMaskIntoConstraints = false
            thumb.addSubview(overlay)
            overlay.addSubview(errLabel)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: thumb.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: thumb.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: thumb.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: thumb.bottomAnchor),
                errLabel.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 6),
                errLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -6),
                errLabel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
            ])
        case .ready, .notApplicable:
            break
        }
    }

    @objc private func videoCardTapped(_ g: UITapGestureRecognizer) {
        guard let id = g.view?.accessibilityIdentifier else { return }
        guard let idx = currentVideoItems.firstIndex(where: { $0.id == id }) else { return }
        onPlayVideo?(currentVideoItems, idx)
    }

    @objc private func videoMenuTapped(_ sender: UIButton) {
        if selectedSegmentIndex == 3 {
            let card = sender.superview?.superview
            guard let itemId = card?.accessibilityIdentifier else { return }
            let sheet = DarkActionSheetViewController()
            sheet.titleText = AppStrings.selectionOfChanges
            sheet.actions = [
                (AppStrings.delete, .destructive, { [weak self] in
                    MediaStorageService.shared.removeFromRecentVideoHistory(itemId: itemId)
                    self?.refreshContent()
                })
            ]
            sheet.modalPresentationStyle = .overFullScreen
            sheet.modalTransitionStyle = .crossDissolve
            present(sheet, animated: true)
            return
        }
        let idx = sender.tag
        guard idx >= 0 && idx < currentVideoItems.count else { return }
        let item = currentVideoItems[idx]
        let sheet = DarkActionSheetViewController()
        sheet.titleText = AppStrings.selectionOfChanges
        sheet.actions = [
            (AppStrings.rename, .default, { [weak self] in self?.showRenameVideo(item: item) }),
            (AppStrings.delete, .destructive, { [weak self] in self?.showDeleteVideo(item: item) })
        ]
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle = .crossDissolve
        present(sheet, animated: true)
    }

    private func showRenameVideo(item: MediaItem) {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.rename
        vc.initialText = item.title
        vc.onSave = { [weak self] name in self?.renameVideo(item: item, newTitle: name) }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func showDeleteVideo(item: MediaItem) {
        let vc = DarkConfirmViewController()
        vc.titleText = AppStrings.areYouSure
        vc.messageText = AppStrings.confirmFileDeletion
        vc.onDelete = { [weak self] in self?.deleteVideo(item: item) }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func renameVideo(item: MediaItem, newTitle: String) {
        var items = MediaStorageService.shared.loadVideoItems()
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].title = newTitle
        MediaStorageService.shared.saveVideoItems(items)
        MediaStorageService.shared.clearLastPlayback(itemId: item.id)
        refreshContent()
    }

    private func deleteVideo(item: MediaItem) {
        MediaStorageService.shared.removeVideoItem(id: item.id)
        refreshContent()
    }

    private func buildAlbumGrid(albums: [Album]) {
        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let cols = numberOfColumns()
        gridStackWidthConstraint?.isActive = false
        gridStackWidthConstraint = gridStack.widthAnchor.constraint(equalToConstant: rowWidthForColumns(cols))
        gridStackWidthConstraint?.isActive = true
        let newCard = makeNewAlbumCard()
        let tapNew = UITapGestureRecognizer(target: self, action: #selector(newAlbumTapped))
        newCard.addGestureRecognizer(tapNew)
        newCard.isUserInteractionEnabled = true
        var rowStack = makeRowStack()
        gridStack.addArrangedSubview(rowStack)
        rowStack.addArrangedSubview(newCard)
        newCard.widthAnchor.constraint(equalToConstant: Self.folderCardWidth).isActive = true
        newCard.setContentHuggingPriority(.required, for: .horizontal)
        for (idx, album) in albums.enumerated() {
            if rowStack.arrangedSubviews.count == numberOfColumns() {
                rowStack = makeRowStack()
                gridStack.addArrangedSubview(rowStack)
            }
            let card = makeAlbumCard(album: album, index: idx)
            rowStack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalToConstant: Self.folderCardWidth).isActive = true
            card.setContentHuggingPriority(.required, for: .horizontal)
        }
        while rowStack.arrangedSubviews.count < numberOfColumns() {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            rowStack.addArrangedSubview(spacer)
        }
    }

    private func makeNewAlbumCard() -> UIView {
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
            card.widthAnchor.constraint(equalToConstant: Self.folderCardWidth),
            card.heightAnchor.constraint(equalToConstant: Self.folderCardHeight),
            coverImageView.topAnchor.constraint(equalTo: card.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalToConstant: Self.folderCardHeight - Self.folderBarHeight),
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

    private func makeAlbumCard(album: Album, index: Int) -> UIView {
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
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let n = album.itemIds.count
        let trackLabel = UILabel()
        trackLabel.text = AppStrings.videoLabelShort(count: n)
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
        menuBtn.addTarget(self, action: #selector(albumMenuTapped(_:)), for: .touchUpInside)
        menuBtn.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(coverImageView)
        card.addSubview(bar)
        bar.addSubview(titleLabel)
        bar.addSubview(playIcon)
        bar.addSubview(trackLabel)
        bar.addSubview(menuBtn)
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Self.folderCardWidth),
            card.heightAnchor.constraint(equalToConstant: Self.folderCardHeight),
            coverImageView.topAnchor.constraint(equalTo: card.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalToConstant: Self.folderCardHeight - Self.folderBarHeight),
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
        let tap = UITapGestureRecognizer(target: self, action: #selector(albumCardTapped(_:)))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true
        return card
    }

    @objc private func albumCardTapped(_ g: UITapGestureRecognizer) {
        guard let id = g.view?.accessibilityIdentifier else { return }
        let albums = MediaStorageService.shared.loadAlbums()
        guard let album = albums.first(where: { $0.id == id }) else { return }
        openAlbum(album)
    }

    @objc private func newAlbumTapped() {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.newPlaylist
        vc.messageText = AppStrings.chooseTitleForNewPlaylist
        vc.placeholder = AppStrings.placeholder
        vc.onSave = { [weak self] name in
            var albums = MediaStorageService.shared.loadAlbums()
            albums.append(Album(id: UUID().uuidString, name: name, itemIds: []))
            MediaStorageService.shared.saveAlbums(albums)
            self?.refreshContent()
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func openAlbum(_ album: Album) {
        let detail = AlbumDetailViewController(album: album)
        detail.delegate = self
        detail.onPlayVideo = onPlayVideo
        navigationController?.pushViewController(detail, animated: true)
    }

    @objc private func albumMenuTapped(_ sender: UIButton) {
        let albums = MediaStorageService.shared.loadAlbums()
        let idx = sender.tag
        guard idx >= 0 && idx < albums.count else { return }
        let album = albums[idx]
        let sheet = DarkActionSheetViewController()
sheet.titleText = AppStrings.selectionOfChanges
            sheet.actions = [
            (AppStrings.rename, .default, { [weak self] in self?.showRenameAlbum(album: album) }),
            (AppStrings.delete, .destructive, { [weak self] in self?.showDeleteAlbum(album: album) })
        ]
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle = .crossDissolve
        present(sheet, animated: true)
    }

    private func showRenameAlbum(album: Album) {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.rename
        vc.initialText = album.name
        vc.onSave = { [weak self] name in
            var albums = MediaStorageService.shared.loadAlbums()
            guard let i = albums.firstIndex(where: { $0.id == album.id }) else { return }
            albums[i].name = name
            MediaStorageService.shared.saveAlbums(albums)
            self?.refreshContent()
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func showDeleteAlbum(album: Album) {
        let vc = DarkConfirmViewController()
        vc.titleText = AppStrings.areYouSure
        vc.messageText = AppStrings.confirmFileDeletion
        vc.onDelete = { [weak self] in
            var albums = MediaStorageService.shared.loadAlbums()
            albums.removeAll { $0.id == album.id }
            MediaStorageService.shared.saveAlbums(albums)
            self?.refreshContent()
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func buildFolderGrid(folders: [MediaFolder]) {
        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let cols = numberOfColumns()
        gridStackWidthConstraint?.isActive = false
        gridStackWidthConstraint = gridStack.widthAnchor.constraint(equalToConstant: rowWidthForColumns(cols))
        gridStackWidthConstraint?.isActive = true
        let newCard = makeNewFolderCard()
        let tapNew = UITapGestureRecognizer(target: self, action: #selector(newFolderTapped))
        newCard.addGestureRecognizer(tapNew)
        newCard.isUserInteractionEnabled = true
        var rowStack = makeRowStack()
        gridStack.addArrangedSubview(rowStack)
        rowStack.addArrangedSubview(newCard)
        newCard.widthAnchor.constraint(equalToConstant: Self.folderCardWidth).isActive = true
        newCard.setContentHuggingPriority(.required, for: .horizontal)
        for (idx, folder) in folders.enumerated() {
            if rowStack.arrangedSubviews.count == numberOfColumns() {
                rowStack = makeRowStack()
                gridStack.addArrangedSubview(rowStack)
            }
            let card = makeFolderCard(folder: folder, index: idx)
            rowStack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalToConstant: Self.folderCardWidth).isActive = true
            card.setContentHuggingPriority(.required, for: .horizontal)
        }
        while rowStack.arrangedSubviews.count < numberOfColumns() {
            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            rowStack.addArrangedSubview(spacer)
        }
    }

    private func makeNewFolderCard() -> UIView {
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
        label.text = AppStrings.newFolder
        label.font = AppFonts.semibold(14)
        label.textColor = .white
        label.fitTextWithinBounds(multiline: true)
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bar)
        bar.addSubview(label)
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Self.folderCardWidth),
            card.heightAnchor.constraint(equalToConstant: Self.folderCardHeight),
            coverImageView.topAnchor.constraint(equalTo: card.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalToConstant: Self.folderCardHeight - Self.folderBarHeight),
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

    private static let folderCardWidth: CGFloat = 158
    private static let folderCardHeight: CGFloat = 135
    private static let folderBarHeight: CGFloat = 38
    private static let cardBarColorTemplate = UIColor(red: 0x18/255, green: 0x0C/255, blue: 0x28/255, alpha: 0.65)

    private func makeFolderCard(folder: MediaFolder, index: Int) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        card.layer.cornerRadius = Self.cardCornerRadius
        card.clipsToBounds = true
        card.accessibilityIdentifier = folder.id
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
        titleLabel.text = folder.name
        titleLabel.font = AppFonts.semibold(14)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.fitTextWithinBounds(multiline: false)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let n = folder.itemIds.count
        let trackLabel = UILabel()
        trackLabel.text = AppStrings.videoLabelShort(count: n)
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
        menuBtn.addTarget(self, action: #selector(folderMenuTapped(_:)), for: .touchUpInside)
        menuBtn.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(coverImageView)
        card.addSubview(bar)
        bar.addSubview(titleLabel)
        bar.addSubview(playIcon)
        bar.addSubview(trackLabel)
        bar.addSubview(menuBtn)
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Self.folderCardWidth),
            card.heightAnchor.constraint(equalToConstant: Self.folderCardHeight),
            coverImageView.topAnchor.constraint(equalTo: card.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalToConstant: Self.folderCardHeight - Self.folderBarHeight),
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
        let tap = UITapGestureRecognizer(target: self, action: #selector(folderCardTapped(_:)))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true
        return card
    }

    @objc private func folderCardTapped(_ g: UITapGestureRecognizer) {
        guard let id = g.view?.accessibilityIdentifier else { return }
        let folders = MediaStorageService.shared.loadFolders()
        guard let folder = folders.first(where: { $0.id == id }) else { return }
        openFolder(folder)
    }

    @objc private func newFolderTapped() {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.newFolder
        vc.placeholder = AppStrings.placeholder
        vc.onSave = { [weak self] name in
            var folders = MediaStorageService.shared.loadFolders()
            folders.append(MediaFolder(id: UUID().uuidString, name: name, itemIds: []))
            MediaStorageService.shared.saveFolders(folders)
            self?.refreshContent()
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    @objc private func folderMenuTapped(_ sender: UIButton) {
        let folders = MediaStorageService.shared.loadFolders()
        let idx = sender.tag
        guard idx >= 0 && idx < folders.count else { return }
        let folder = folders[idx]
        let sheet = DarkActionSheetViewController()
sheet.titleText = AppStrings.selectionOfChanges
            sheet.actions = [
            (AppStrings.rename, .default, { [weak self] in self?.showRenameFolder(folder: folder) }),
            (AppStrings.delete, .destructive, { [weak self] in self?.showDeleteFolder(folder: folder) })
        ]
        sheet.modalPresentationStyle = .overFullScreen
        sheet.modalTransitionStyle = .crossDissolve
        present(sheet, animated: true)
    }

    private func showRenameFolder(folder: MediaFolder) {
        let vc = DarkAlertViewController()
        vc.titleText = AppStrings.rename
        vc.initialText = folder.name
        vc.onSave = { [weak self] name in
            var folders = MediaStorageService.shared.loadFolders()
            guard let i = folders.firstIndex(where: { $0.id == folder.id }) else { return }
            folders[i].name = name
            MediaStorageService.shared.saveFolders(folders)
            self?.refreshContent()
        }
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func showDeleteFolder(folder: MediaFolder) {
        let vc = DarkConfirmViewController()
        vc.titleText = AppStrings.areYouSure
        vc.messageText = AppStrings.confirmFileDeletion
        vc.onDelete = { [weak self] in
            var folders = MediaStorageService.shared.loadFolders()
            folders.removeAll { $0.id == folder.id }
            MediaStorageService.shared.saveFolders(folders)
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
    }

}
