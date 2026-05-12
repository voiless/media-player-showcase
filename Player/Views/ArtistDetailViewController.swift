import UIKit

final class ArtistDetailViewController: UIViewController {

    private let artistName: String
    private var tracks: [MediaItem] = []

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

    init(artistName: String) {
        self.artistName = artistName
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
        navigationItem.title = artistName
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.barTintColor = .black
        navigationController?.navigationBar.isTranslucent = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ArtistTrackCell.self, forCellReuseIdentifier: ArtistTrackCell.reuseId)
        reloadTracks()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        reloadTracks()
    }

    private func reloadTracks() {
        let all = MediaStorageService.shared.loadAudioItems()
        tracks = all.filter { ($0.author ?? "").trimmingCharacters(in: .whitespaces).lowercased() == artistName.trimmingCharacters(in: .whitespaces).lowercased() }
        tableView.reloadData()
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
}

extension ArtistDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tracks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ArtistTrackCell.reuseId, for: indexPath) as! ArtistTrackCell
        let item = tracks[indexPath.row]
        cell.configure(title: item.displayTitle, subtitle: item.author, coverURL: item.coverImageURL)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < tracks.count else { return }
        onPlayAudio?(tracks, indexPath.row)
    }
}

private final class ArtistTrackCell: UITableViewCell {
    static let reuseId = "ArtistTrackCell"

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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.addSubview(thumbView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            thumbView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: 48),
            thumbView.heightAnchor.constraint(equalToConstant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: thumbView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(title: String, subtitle: String?, coverURL: URL?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle ?? ""
        thumbView.image = coverURL.flatMap { UIImage(contentsOfFile: $0.path) } ?? DefaultCover.audioBackground
    }
}
