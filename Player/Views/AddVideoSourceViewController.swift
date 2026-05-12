import UIKit

protocol AddVideoSourceDelegate: AnyObject {
    func addVideoSourceDidSelectFiles()
    func addVideoSourceDidSelectFolder()
}

enum AddMediaMode {
    case video
    case audio
}

final class AddVideoSourceViewController: UIViewController {

    weak var delegate: AddVideoSourceDelegate?
    private let mode: AddMediaMode

    private static let buttonInsetPhone: CGFloat = 10
    private static let buttonInsetPad: CGFloat = 93
    private static let filesHeight: CGFloat = 50
    private static let cancelHeight: CGFloat = 60
    private static let gap: CGFloat = 10
    private static let filesCornerRadius: CGFloat = 10
    private static let cancelCornerRadius: CGFloat = 15
    private static let buttonBg = UIColor(white: 1, alpha: 0x0D/255)
    private static let gradientStart = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1)
    private static let gradientEnd = UIColor(red: 0xA2/255, green: 0x84/255, blue: 0xF6/255, alpha: 1)
    private static let iconSize: CGFloat = 24

    private static func icon24(named name: String) -> UIImage? {
        guard let img = UIImage(named: name)?.withRenderingMode(.alwaysTemplate) else { return nil }
        let size = CGSize(width: iconSize, height: iconSize)
        let scale = min(size.width / img.size.width, size.height / img.size.height)
        let drawSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let drawOrigin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            img.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }.withRenderingMode(.alwaysTemplate)
    }

    init(mode: AddMediaMode = .video) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    private static let backgroundHex = UIColor(red: 0x0F/255, green: 0x08/255, blue: 0x17/255, alpha: 1)
    private static let titleColor = UIColor(white: 1, alpha: 0x80/255)

    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = AddVideoSourceViewController.backgroundHex
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        let text = mode == .video ? AppStrings.addVideoFrom : AppStrings.addAudioFrom
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 16
        paragraph.maximumLineHeight = 16
        paragraph.alignment = .center
        l.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: AppFonts.regular(12),
                .foregroundColor: Self.titleColor,
                .paragraphStyle: paragraph,
                .kern: 0
            ]
        )
        l.textAlignment = .center
        l.fitTextWithinBounds(multiline: true)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var filesButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.setTitle(AppStrings.files, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = AppFonts.regular(17)
        b.fitTitleWithinBounds(maxLines: 2)
        b.backgroundColor = Self.buttonBg
        b.layer.cornerRadius = Self.filesCornerRadius
        b.contentHorizontalAlignment = .left
        b.semanticContentAttribute = .forceLeftToRight
        b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 30, bottom: 10, right: 30)
        b.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(Self.icon24(named: "files-image"), for: .normal)
        b.tintColor = .white
        return b
    }()

    private lazy var folderButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.setTitle(AppStrings.addFolder, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = AppFonts.regular(17)
        b.fitTitleWithinBounds(maxLines: 2)
        b.backgroundColor = Self.buttonBg
        b.layer.cornerRadius = Self.filesCornerRadius
        b.contentHorizontalAlignment = .left
        b.semanticContentAttribute = .forceLeftToRight
        b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 30, bottom: 10, right: 30)
        b.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(Self.icon24(named: "folder-image"), for: .normal)
        b.tintColor = .white
        return b
    }()

    private let cancelButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.setTitle(AppStrings.cancel, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = AppFonts.semibold(17)
        b.fitTitleWithinBounds(maxLines: 2)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.contentHorizontalAlignment = .center
        b.contentEdgeInsets = UIEdgeInsets(top: 23, left: 20, bottom: 23, right: 20)
        return b
    }()

    private let gradientLayer = CAGradientLayer()

    private let tapOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let presentDuration: TimeInterval = 0.35
    private let dismissDuration: TimeInterval = 0.28

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(tapOverlay)
        view.addSubview(containerView)
        let tapBg = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        tapOverlay.addGestureRecognizer(tapBg)
        containerView.addSubview(titleLabel)
        containerView.addSubview(filesButton)
        containerView.addSubview(folderButton)
        containerView.addSubview(cancelButton)
        cancelButton.layer.insertSublayer(gradientLayer, at: 0)
        gradientLayer.colors = [Self.gradientStart.cgColor, Self.gradientEnd.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.13)
        let buttonInset: CGFloat = traitCollection.userInterfaceIdiom == .pad ? Self.buttonInsetPad : Self.buttonInsetPhone
        NSLayoutConstraint.activate([
            tapOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            tapOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tapOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tapOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            filesButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            filesButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: buttonInset),
            filesButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -buttonInset),
            filesButton.heightAnchor.constraint(equalToConstant: Self.filesHeight),
            folderButton.topAnchor.constraint(equalTo: filesButton.bottomAnchor, constant: Self.gap),
            folderButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: buttonInset),
            folderButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -buttonInset),
            folderButton.heightAnchor.constraint(equalToConstant: Self.filesHeight),
            cancelButton.topAnchor.constraint(equalTo: folderButton.bottomAnchor, constant: Self.gap),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: buttonInset),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -buttonInset),
            cancelButton.heightAnchor.constraint(equalToConstant: Self.cancelHeight),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
        filesButton.addTarget(self, action: #selector(filesTapped), for: .touchUpInside)
        folderButton.addTarget(self, action: #selector(folderTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.layoutIfNeeded()
        containerView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: presentDuration, delay: 0, options: .curveEaseOut) {
            self.view.backgroundColor = Self.backgroundHex.withAlphaComponent(0.92)
            self.containerView.transform = .identity
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cancelButton.layer.cornerRadius = Self.cancelCornerRadius
        cancelButton.clipsToBounds = true
        gradientLayer.frame = cancelButton.bounds
        gradientLayer.cornerRadius = Self.cancelCornerRadius
    }

    private func dismissWithAnimation(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: dismissDuration, delay: 0, options: .curveEaseIn) {
            self.view.backgroundColor = .clear
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
        } completion: { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }

    @objc private func filesTapped() {
        let delegate = self.delegate
        dismissWithAnimation {
            DispatchQueue.main.async { delegate?.addVideoSourceDidSelectFiles() }
        }
    }

    @objc private func folderTapped() {
        let delegate = self.delegate
        dismissWithAnimation {
            DispatchQueue.main.async { delegate?.addVideoSourceDidSelectFolder() }
        }
    }

    @objc private func cancelTapped() {
        dismissWithAnimation()
    }
}
