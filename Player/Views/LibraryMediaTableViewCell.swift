import UIKit

/// Ячейка видео в библиотеке: затемнение и статус конвертации для PiP.
final class LibraryMediaTableViewCell: UITableViewCell {

    static let reuseId = "LibraryMediaCell"

    private let spinner = UIActivityIndicatorView(style: .medium)
    private let dimOverlay = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        dimOverlay.translatesAutoresizingMaskIntoConstraints = false
        dimOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimOverlay.isUserInteractionEnabled = false
        contentView.addSubview(dimOverlay)
        contentView.addSubview(spinner)
        NSLayoutConstraint.activate([
            dimOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            dimOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dimOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dimOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            spinner.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        selectionStyle = .default
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(video item: MediaItem) {
        textLabel?.text = item.title
        textLabel?.alpha = 1
        detailTextLabel?.alpha = 1
        switch item.pipPreparation {
        case .pending:
            contentView.alpha = 0.65
            dimOverlay.isHidden = false
            spinner.startAnimating()
            let pct = PiPConversionService.shared.progressPercent(forItemId: item.id) ?? 0
            if pct > 0 {
                detailTextLabel?.text = AppStrings.pipPreparingProgressLabel(percent: pct)
            } else if let author = item.author, !author.isEmpty {
                detailTextLabel?.text = "\(author) — \(AppStrings.libraryPipPreparing)"
            } else {
                detailTextLabel?.text = AppStrings.libraryPipPreparing
            }
        case .failed:
            contentView.alpha = 0.85
            dimOverlay.isHidden = false
            spinner.stopAnimating()
            detailTextLabel?.text = AppStrings.libraryPipConversionErrorShort
            detailTextLabel?.textColor = .secondaryLabel
        case .ready, .notApplicable:
            contentView.alpha = 1
            dimOverlay.isHidden = true
            spinner.stopAnimating()
            detailTextLabel?.text = item.author
            detailTextLabel?.textColor = .secondaryLabel
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.alpha = 1
        dimOverlay.isHidden = true
        spinner.stopAnimating()
        detailTextLabel?.textColor = .secondaryLabel
        textLabel?.textColor = .label
    }
}
