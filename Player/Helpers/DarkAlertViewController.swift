import UIKit

final class DarkAlertViewController: UIViewController {

    var titleText: String?
    var messageText: String?
    var placeholder: String?
    var initialText: String?
    var onSave: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private static let dialogWidth: CGFloat = 270
    private static let cornerRadius: CGFloat = 15
    private static let dialogTint = UIColor(red: 56/255, green: 56/255, blue: 57/255, alpha: 0.59)
    private static let separatorColor = UIColor(red: 0x38/255, green: 0x38/255, blue: 0x3A/255, alpha: 1)
    private static let primaryBlue = UIColor(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255, alpha: 1)
    private static let secondaryGray = UIColor(red: 0xAE/255, green: 0xAE/255, blue: 0xB2/255, alpha: 1)
    private static let fieldBg = UIColor(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255, alpha: 1)

    private let blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .dark)
        let v = UIVisualEffectView(effect: effect)
        v.layer.cornerRadius = cornerRadius
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let tintOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = DarkAlertViewController.dialogTint
        v.layer.cornerRadius = cornerRadius
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let textField: UITextField = {
        let t = UITextField()
        t.backgroundColor = DarkAlertViewController.fieldBg
        t.textColor = .white
        t.font = AppFonts.regular(17)
        t.attributedPlaceholder = NSAttributedString(
            string: " ",
            attributes: [.foregroundColor: DarkAlertViewController.secondaryGray]
        )
        t.layer.cornerRadius = 8
        t.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        t.leftViewMode = .always
        t.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        t.rightViewMode = .always
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.addSubview(blurView)
        blurView.contentView.addSubview(tintOverlay)
        blurView.contentView.addSubview(contentView)
        tintOverlay.pinToSuperview()
        contentView.pinToSuperview()
        contentView.addSubview(textField)
        textField.placeholder = placeholder ?? AppStrings.placeholder
        textField.text = initialText

        var topAnchor = contentView.topAnchor
        if let t = titleText, !t.isEmpty {
            let lbl = UILabel()
            lbl.text = t
            lbl.font = AppFonts.semibold(17)
            lbl.textColor = .white
            lbl.textAlignment = .center
            lbl.fitTextWithinBounds(multiline: true)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
                lbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                lbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
            ])
            topAnchor = lbl.bottomAnchor
        }
        if let m = messageText, !m.isEmpty {
            let mlbl = UILabel()
            mlbl.text = m
            mlbl.font = AppFonts.regular(14)
            mlbl.textColor = Self.secondaryGray
            mlbl.textAlignment = .center
            mlbl.numberOfLines = 0
            mlbl.lineBreakMode = .byWordWrapping
            mlbl.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(mlbl)
            NSLayoutConstraint.activate([
                mlbl.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                mlbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                mlbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
            ])
            topAnchor = mlbl.bottomAnchor
        }
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textField.heightAnchor.constraint(equalToConstant: 44)
        ])
        topAnchor = textField.bottomAnchor

        let sepH = UIView()
        sepH.backgroundColor = Self.separatorColor
        sepH.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sepH)
        NSLayoutConstraint.activate([
            sepH.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            sepH.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sepH.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            sepH.heightAnchor.constraint(equalToConstant: 1)
        ])

        let saveBtn = TouchTargetButton(type: .system)
        saveBtn.setTitle(AppStrings.save, for: .normal)
        saveBtn.setTitleColor(Self.primaryBlue, for: .normal)
        saveBtn.titleLabel?.font = AppFonts.semibold(17)
        saveBtn.fitTitleWithinBounds(maxLines: 2)
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        let cancelBtn = TouchTargetButton(type: .system)
        cancelBtn.setTitle(AppStrings.cancel, for: .normal)
        cancelBtn.setTitleColor(Self.secondaryGray, for: .normal)
        cancelBtn.titleLabel?.font = AppFonts.regular(17)
        cancelBtn.fitTitleWithinBounds(maxLines: 2)
        cancelBtn.contentHorizontalAlignment = .center
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        let sepV = UIView()
        sepV.backgroundColor = Self.separatorColor
        sepV.translatesAutoresizingMaskIntoConstraints = false
        let btnContainer = UIView()
        btnContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(btnContainer)
        btnContainer.addSubview(saveBtn)
        btnContainer.addSubview(sepV)
        btnContainer.addSubview(cancelBtn)
        NSLayoutConstraint.activate([
            sepH.bottomAnchor.constraint(equalTo: btnContainer.topAnchor),
            btnContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            btnContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            btnContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            btnContainer.heightAnchor.constraint(equalToConstant: 50),
            saveBtn.leadingAnchor.constraint(equalTo: btnContainer.leadingAnchor),
            saveBtn.topAnchor.constraint(equalTo: btnContainer.topAnchor),
            saveBtn.bottomAnchor.constraint(equalTo: btnContainer.bottomAnchor),
            saveBtn.trailingAnchor.constraint(equalTo: sepV.leadingAnchor),
            sepV.widthAnchor.constraint(equalToConstant: 1),
            sepV.topAnchor.constraint(equalTo: btnContainer.topAnchor),
            sepV.bottomAnchor.constraint(equalTo: btnContainer.bottomAnchor),
            sepV.centerXAnchor.constraint(equalTo: btnContainer.centerXAnchor),
            cancelBtn.leadingAnchor.constraint(equalTo: sepV.trailingAnchor),
            cancelBtn.topAnchor.constraint(equalTo: btnContainer.topAnchor),
            cancelBtn.bottomAnchor.constraint(equalTo: btnContainer.bottomAnchor),
            cancelBtn.trailingAnchor.constraint(equalTo: btnContainer.trailingAnchor)
        ])

        NSLayoutConstraint.activate([
            blurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blurView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            blurView.widthAnchor.constraint(equalToConstant: Self.dialogWidth),
            blurView.topAnchor.constraint(equalTo: contentView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        let contentTop = contentView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor)
        let contentLead = contentView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor)
        let contentTrail = contentView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor)
        let contentBot = contentView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor)
        NSLayoutConstraint.activate([contentTop, contentLead, contentTrail, contentBot])
        let tintTop = tintOverlay.topAnchor.constraint(equalTo: blurView.contentView.topAnchor)
        let tintLead = tintOverlay.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor)
        let tintTrail = tintOverlay.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor)
        let tintBot = tintOverlay.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor)
        NSLayoutConstraint.activate([tintTop, tintLead, tintTrail, tintBot])

        let tapBg = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        view.addGestureRecognizer(tapBg)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    @objc private func saveTapped() {
        let name = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return }
        view.isUserInteractionEnabled = false
        let callback = onSave
        onSave = nil
        onCancel = nil
        dismiss(animated: true) {
            DispatchQueue.main.async { callback?(name) }
        }
    }

    @objc private func cancelTapped() {
        view.isUserInteractionEnabled = false
        let callback = onCancel
        onSave = nil
        onCancel = nil
        dismiss(animated: true) {
            DispatchQueue.main.async { callback?() }
        }
    }
}

private extension UIView {
    func pinToSuperview() {
        guard let s = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: s.topAnchor),
            leadingAnchor.constraint(equalTo: s.leadingAnchor),
            trailingAnchor.constraint(equalTo: s.trailingAnchor),
            bottomAnchor.constraint(equalTo: s.bottomAnchor)
        ])
    }
}
