import UIKit

final class DarkActionSheetViewController: UIViewController {

    var titleText: String?
    var actions: [(title: String, style: UIAlertAction.Style, handler: (() -> Void)?)] = []
    var onDismiss: (() -> Void)?

    private static let buttonInsetPhone: CGFloat = 10
    private static let buttonInsetPad: CGFloat = 93
    private static let buttonHeight: CGFloat = 50
    private static let gap: CGFloat = 10
    private static let buttonCornerRadius: CGFloat = 10
    private static let containerCornerRadius: CGFloat = 16
    private static let backgroundHex = UIColor(red: 0x0F/255, green: 0x08/255, blue: 0x17/255, alpha: 1)
    private static let titleColor = UIColor(white: 1, alpha: 0x80/255)
    private static let buttonBg = UIColor(white: 1, alpha: 0x0D/255)
    private static let cancelHeight: CGFloat = 60
    private static let cancelCornerRadius: CGFloat = 15
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

    private static func iconForAction(title: String, style: UIAlertAction.Style) -> UIImage? {
        if title.lowercased().contains("rename") || title == AppStrings.rename {
            return icon24(named: "pencil-image")
        }
        if style == .destructive || title.lowercased().contains("delete") || title == AppStrings.delete {
            return icon24(named: "trash-image")
        }
        return nil
    }

    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = DarkActionSheetViewController.backgroundHex
        v.layer.cornerRadius = containerCornerRadius
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let scrollContent = UIView()
    private let buttonsStack = UIStackView()
    private var cancelButtonGradients: [(UIButton, CAGradientLayer)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(containerView)
        containerView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        buttonsStack.axis = .vertical
        buttonsStack.spacing = Self.gap
        buttonsStack.alignment = .fill
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        scrollContent.addSubview(buttonsStack)

        var topAnchor = scrollContent.topAnchor
        if let t = titleText, !t.isEmpty {
            let lbl = UILabel()
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = 16
            paragraph.maximumLineHeight = 16
            paragraph.alignment = .center
            lbl.attributedText = NSAttributedString(
                string: t,
                attributes: [
                    .font: AppFonts.regular(12),
                    .foregroundColor: Self.titleColor,
                    .paragraphStyle: paragraph,
                    .kern: 0
                ]
            )
            lbl.textAlignment = .center
            lbl.fitTextWithinBounds(multiline: true)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            scrollContent.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.topAnchor.constraint(equalTo: scrollContent.topAnchor, constant: 24),
                lbl.leadingAnchor.constraint(equalTo: scrollContent.leadingAnchor, constant: 18),
                lbl.trailingAnchor.constraint(equalTo: scrollContent.trailingAnchor, constant: -18)
            ])
            topAnchor = lbl.bottomAnchor
        }
        let buttonInset: CGFloat = traitCollection.userInterfaceIdiom == .pad ? Self.buttonInsetPad : Self.buttonInsetPhone
        NSLayoutConstraint.activate([
            buttonsStack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            buttonsStack.leadingAnchor.constraint(equalTo: scrollContent.leadingAnchor, constant: buttonInset),
            buttonsStack.trailingAnchor.constraint(equalTo: scrollContent.trailingAnchor, constant: -buttonInset),
            buttonsStack.bottomAnchor.constraint(equalTo: scrollContent.bottomAnchor)
        ])

        for (idx, act) in actions.enumerated() {
            let isCancel = act.title == AppStrings.cancel
            let hasIcon = !isCancel && Self.iconForAction(title: act.title, style: act.style) != nil
            let btn = TouchTargetButton(type: .system)
            btn.setTitle(act.title, for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = isCancel ? AppFonts.semibold(17) : AppFonts.regular(17)
            btn.fitTitleWithinBounds(maxLines: 2)
            btn.contentHorizontalAlignment = isCancel ? .center : .left
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.tag = idx
            btn.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
            if isCancel {
                btn.contentEdgeInsets = UIEdgeInsets(top: 23, left: 20, bottom: 23, right: 20)
                btn.layer.cornerRadius = Self.cancelCornerRadius
                btn.clipsToBounds = true
                let gradientLayer = CAGradientLayer()
                gradientLayer.colors = [Self.gradientStart.cgColor, Self.gradientEnd.cgColor]
                gradientLayer.startPoint = CGPoint(x: 0, y: 0)
                gradientLayer.endPoint = CGPoint(x: 1, y: 0.13)
                btn.layer.insertSublayer(gradientLayer, at: 0)
                cancelButtonGradients.append((btn, gradientLayer))
            } else {
                btn.backgroundColor = Self.buttonBg
                btn.layer.cornerRadius = Self.buttonCornerRadius
                btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 30, bottom: 10, right: 30)
                btn.titleEdgeInsets = hasIcon ? UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0) : .zero
                if let icon = Self.iconForAction(title: act.title, style: act.style) {
                    btn.setImage(icon, for: .normal)
                    btn.tintColor = .white
                }
            }
            buttonsStack.addArrangedSubview(btn)
            btn.heightAnchor.constraint(equalToConstant: isCancel ? Self.cancelHeight : Self.buttonHeight).isActive = true
        }

        let topOverlay = UIView()
        topOverlay.backgroundColor = .clear
        topOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(topOverlay, at: 0)
        let tapBg = UITapGestureRecognizer(target: self, action: #selector(dismissTapped))
        topOverlay.addGestureRecognizer(tapBg)
        NSLayoutConstraint.activate([
            topOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            topOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            scrollContent.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            scrollContent.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }

    private let presentDuration: TimeInterval = 0.35
    private let dismissDuration: TimeInterval = 0.28

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for (btn, layer) in cancelButtonGradients {
            layer.frame = btn.bounds
            layer.cornerRadius = Self.cancelCornerRadius
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.layoutIfNeeded()
        containerView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: presentDuration, delay: 0, options: .curveEaseOut) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            self.containerView.transform = .identity
        }
    }

    private func dismissWithAnimation(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: dismissDuration, delay: 0, options: .curveEaseIn) {
            self.view.backgroundColor = .clear
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
        } completion: { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }

    @objc private func actionTapped(_ sender: UIButton) {
        let idx = sender.tag
        guard idx >= 0, idx < actions.count else { return }
        view.isUserInteractionEnabled = false
        let handler = actions[idx].handler
        actions = []
        onDismiss = nil
        dismissWithAnimation {
            DispatchQueue.main.async { handler?() }
        }
    }

    @objc private func dismissTapped() {
        view.isUserInteractionEnabled = false
        let callback = onDismiss
        actions = []
        onDismiss = nil
        dismissWithAnimation {
            DispatchQueue.main.async { callback?() }
        }
    }
}
