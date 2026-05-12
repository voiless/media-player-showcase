import MessageUI
import StoreKit
import UIKit

final class SettingsViewController: UIViewController, TabContentControlling {

    var onPlusTapped: (() -> Void)?

    private let purpleAccent = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1.0)
    private static let containerBg = UIColor(red: 0x4E/255, green: 0x28/255, blue: 0x7C/255, alpha: 0.22)
    private static let supportAccent = UIColor(red: 0x7B/255, green: 0x82/255, blue: 0xDB/255, alpha: 1)

    private let backgroundImageView: UIImageView = {
        let v = UIImageView()
        v.image = UIImage(named: "load_back")
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = AppFonts.bold(22)
        l.textColor = .white
        l.fitTextWithinBounds(multiline: true)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.showsVerticalScrollIndicator = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 20
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private var backgroundPlaySwitch: UISwitch?
    private var backgroundPlayOn: Bool { MediaStorageService.shared.backgroundPlayEnabled() }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .black
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(backgroundImageView)
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        titleLabel.text = AppStrings.settings
        buildSettingsList()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let sw = backgroundPlaySwitch, sw.bounds.width > 0, sw.bounds.height > 0 else { return }
        for subview in sw.subviews {
            let w = subview.bounds.width
            let h = subview.bounds.height
            if w > 0, h > 0, w < sw.bounds.width * 0.9 {
                subview.layer.cornerRadius = min(w, h) / 2
                subview.clipsToBounds = true
                break
            }
        }
    }

    private func settingsIcon(_ name: String) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        return UIImage(systemName: name, withConfiguration: config)?.withRenderingMode(.alwaysTemplate)
    }

    private func settingsAssetIcon(_ name: String) -> UIImage? {
        UIImage(named: name)?.withRenderingMode(.alwaysTemplate)
    }

    private func buildSettingsList() {
        let rows: [(iconAsset: String?, iconSF: String?, title: String, showChevron: Bool, isToggle: Bool, iconSize: CGFloat)] = [
            ("backplay-icon", nil, AppStrings.backgroundPlay, false, true, 24),
            ("language-icon", nil, AppStrings.language, true, false, 24),
            ("feedback-icon", nil, AppStrings.feedback, true, false, 23),
            ("delete_cache-icon", nil, AppStrings.clearCache, false, false, 23),
            ("rate-app-icon", nil, AppStrings.rateTheApp, false, false, 24),
            ("restore-icon", nil, AppStrings.restoringPurchases, false, false, 24)
        ]

        let mainCard = UIView()
        mainCard.backgroundColor = Self.containerBg
        mainCard.layer.cornerRadius = AppColors.cardCornerRadius
        mainCard.clipsToBounds = true
        mainCard.translatesAutoresizingMaskIntoConstraints = false

        let rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 0
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        mainCard.addSubview(rowsStack)

        for (idx, row) in rows.enumerated() {
            let iconImage: UIImage? = row.iconAsset.flatMap { settingsAssetIcon($0) } ?? row.iconSF.flatMap { settingsIcon($0) }
            let rowView = makeSettingsRow(
                icon: iconImage,
                title: row.title,
                showChevron: row.showChevron,
                isToggle: row.isToggle,
                tag: idx,
                iconSize: row.iconSize
            )
            rowsStack.addArrangedSubview(rowView)
            if idx < rows.count - 1 {
                let sep = UIView()
                sep.backgroundColor = UIColor.white.withAlphaComponent(0.08)
                sep.translatesAutoresizingMaskIntoConstraints = false
                sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
                rowsStack.addArrangedSubview(sep)
            }
        }

        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: mainCard.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: mainCard.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: mainCard.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: mainCard.bottomAnchor)
        ])
        contentStack.addArrangedSubview(mainCard)

        let supportContainer = makeSupportButton()
        contentStack.addArrangedSubview(supportContainer)

        let otherRow = makeSettingsRow(
            icon: settingsAssetIcon("other-icon"),
            title: AppStrings.portfolioDemos,
            showChevron: true,
            isToggle: false,
            tag: 100,
            iconSize: 24
        )
        let otherContainer = UIView()
        otherContainer.backgroundColor = Self.containerBg
        otherContainer.layer.cornerRadius = AppColors.cardCornerRadius
        otherContainer.clipsToBounds = true
        otherContainer.translatesAutoresizingMaskIntoConstraints = false
        otherContainer.addSubview(otherRow)
        NSLayoutConstraint.activate([
            otherRow.topAnchor.constraint(equalTo: otherContainer.topAnchor),
            otherRow.leadingAnchor.constraint(equalTo: otherContainer.leadingAnchor),
            otherRow.trailingAnchor.constraint(equalTo: otherContainer.trailingAnchor),
            otherRow.bottomAnchor.constraint(equalTo: otherContainer.bottomAnchor)
        ])
        contentStack.addArrangedSubview(otherContainer)
    }

    private func makeSettingsRow(icon: UIImage?, title: String, showChevron: Bool, isToggle: Bool, tag: Int, iconSize: CGFloat = 24) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let iconView = UIImageView(image: icon)
        iconView.tintColor = purpleAccent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconView)

        let label = UILabel()
        label.text = title
        label.font = AppFonts.regular(17)
        label.textColor = .white
        label.fitTextWithinBounds(multiline: false)
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)

        if isToggle {
            let sw = UISwitch()
            sw.isOn = backgroundPlayOn
            sw.onTintColor = purpleAccent
            sw.translatesAutoresizingMaskIntoConstraints = false
            sw.addAction(UIAction { _ in
                MediaStorageService.shared.setBackgroundPlayEnabled(sw.isOn)
            }, for: .valueChanged)
            row.addSubview(sw)
            backgroundPlaySwitch = sw
            let trailingConstant: CGFloat = (traitCollection.userInterfaceIdiom == .pad) ? -16 : -6
            NSLayoutConstraint.activate([
                sw.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: trailingConstant),
                sw.centerYAnchor.constraint(equalTo: row.centerYAnchor)
            ])
        } else if showChevron {
            let backImg = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
            let arrowView = UIImageView(image: backImg)
            arrowView.tintColor = .white
            arrowView.contentMode = .scaleAspectFit
            arrowView.transform = CGAffineTransform(rotationAngle: .pi)
            arrowView.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(arrowView)
            NSLayoutConstraint.activate([
                arrowView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
                arrowView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                arrowView.widthAnchor.constraint(equalToConstant: 20),
                arrowView.heightAnchor.constraint(equalToConstant: 20)
            ])
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(settingsRowTapped(_:)))
        row.addGestureRecognizer(tap)
        row.isUserInteractionEnabled = true
        row.tag = tag

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -68)
        ])
        return row
    }

    private func makeSupportButton() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let btn = TouchTargetButton(type: .system)
        btn.backgroundColor = Self.supportAccent
        btn.layer.cornerRadius = 10
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(supportTapped), for: .touchUpInside)

        let iconSize: CGFloat = 44
        let supportImageView = UIImageView(image: UIImage(named: "feedback-icon")?.withRenderingMode(.alwaysOriginal))
        supportImageView.contentMode = .scaleAspectFit
        supportImageView.clipsToBounds = true
        supportImageView.translatesAutoresizingMaskIntoConstraints = false
        btn.addSubview(supportImageView)

        let titleLabel = UILabel()
        titleLabel.text = AppStrings.joinSupport
        titleLabel.font = AppFonts.semibold(16)
        titleLabel.textColor = .white
        titleLabel.fitTextWithinBounds(multiline: true)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        btn.addSubview(titleLabel)

        let greenDot = UIView()
        greenDot.backgroundColor = UIColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1)
        greenDot.layer.cornerRadius = 4
        greenDot.translatesAutoresizingMaskIntoConstraints = false
        let onlineLabel = UILabel()
        onlineLabel.text = AppStrings.activeCommunityCount
        onlineLabel.font = AppFonts.regular(12)
        onlineLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        onlineLabel.fitTextWithinBounds(multiline: false)
        onlineLabel.translatesAutoresizingMaskIntoConstraints = false

        let onlineRow = UIStackView(arrangedSubviews: [greenDot, onlineLabel])
        onlineRow.axis = .horizontal
        onlineRow.spacing = 6
        onlineRow.alignment = .center
        onlineRow.translatesAutoresizingMaskIntoConstraints = false
        greenDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        greenDot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let textStack = UIStackView(arrangedSubviews: [titleLabel, onlineRow])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false
        btn.addSubview(textStack)

        NSLayoutConstraint.activate([
            supportImageView.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 16),
            supportImageView.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            supportImageView.widthAnchor.constraint(equalToConstant: iconSize),
            supportImageView.heightAnchor.constraint(equalToConstant: iconSize),
            textStack.leadingAnchor.constraint(equalTo: supportImageView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: btn.trailingAnchor, constant: -16)
        ])
        container.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: container.topAnchor),
            btn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            btn.heightAnchor.constraint(equalToConstant: 69),
            btn.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    @objc private func settingsRowTapped(_ g: UITapGestureRecognizer) {
        guard let row = g.view else { return }
        let tag = row.tag
        if tag == 1 {
            let langVC = LanguageSettingsViewController()
            let nav = UINavigationController(rootViewController: langVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        } else if tag == 2 {
            openFeedbackMail()
        } else if tag == 3 {
            showClearCacheConfirmation()
        } else if tag == 4 {
            requestAppReview()
        } else if tag == 5 {
            restorePurchasesTapped()
        } else if tag == 100 {
            let demosVC = PortfolioDemosViewController()
            let nav = UINavigationController(rootViewController: demosVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    private func showClearCacheConfirmation() {
        let alert = UIAlertController(
            title: AppStrings.clearCacheConfirmTitle,
            message: AppStrings.clearCacheConfirmMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: AppStrings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: AppStrings.clear, style: .destructive) { [weak self] _ in
            self?.performClearCache()
        })
        present(alert, animated: true)
    }

    private func performClearCache() {
        PlayerService.shared.clearPlayback()
        MediaStorageService.shared.clearAllMediaData()
        MediaCoverCache.clearAll()
        URLCache.shared.removeAllCachedResponses()
        if AppConfig.onboardingDisabled {
            UserDefaults.standard.set(true, forKey: MediaStorageService.onboardingCompletedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: MediaStorageService.onboardingCompletedKey)
        }
        NotificationCenter.default.post(name: MediaStorageService.mediaCoversDidUpdateNotification, object: nil)
    }

    private static let feedbackEmail = "portfolio@example.invalid"

    private func openFeedbackMail() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([Self.feedbackEmail])
            present(mail, animated: true)
        } else if let url = URL(string: "mailto:\(Self.feedbackEmail)") {
            UIApplication.shared.open(url)
        }
    }

    private func openSupportURL() {
        guard let url = URL(string: AppStrings.appSupportURL) else { return }
        UIApplication.shared.open(url)
    }

    private func requestAppReview() {
        if let windowScene = view.window?.windowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }

    private func restorePurchasesTapped() {
        SubscriptionStore.shared.restorePurchases { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let message = success ? AppStrings.restoreSuccess : AppStrings.restoreFailed
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: AppStrings.ok, style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    @objc private func supportTapped() {
        openSupportURL()
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}

private let settingsCellBackground = UIColor(red: 0x4A/255, green: 0x29/255, blue: 0x7B/255, alpha: 0.8)
private let languageAndAppsCellBg = UIColor(red: 0x4E/255, green: 0x28/255, blue: 0x7C/255, alpha: 0.22)

final class LanguageSettingsViewController: UIViewController {

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
        if #available(iOS 15.0, *) { t.sectionHeaderTopPadding = 0 }
        return t
    }()

    private static let languageCardCornerRadius: CGFloat = 5
    private var languages: [String] { AppStrings.languageNames }
    private var selectedIndex: Int {
        get {
            guard let code = AppStrings.preferredLanguageCode,
                  let idx = AppStrings.languageCodes.firstIndex(of: code) else { return 1 }
            return idx
        }
        set {
            guard newValue >= 0, newValue < AppStrings.languageCodes.count else { return }
            AppStrings.preferredLanguageCode = AppStrings.languageCodes[newValue]
        }
    }
    private let purpleAccent = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1.0)

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
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem.touchTargetBackChevron(target: self, action: #selector(backTapped))
        navigationItem.leftBarButtonItem?.tintColor = .white
        title = AppStrings.settings
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.barTintColor = .clear
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        tableView.delegate = self
        tableView.dataSource = self
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }
}

extension LanguageSettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        languages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = languageAndAppsCellBg
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = AppFonts.regular(17)
        cell.textLabel?.text = languages[indexPath.row]
        cell.selectionStyle = .none
        cell.fitTextLabelsWithinBounds()
        cell.layer.cornerRadius = Self.languageCardCornerRadius
        cell.clipsToBounds = true
        if indexPath.row == 0 {
            cell.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else if indexPath.row == languages.count - 1 {
            cell.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            cell.layer.maskedCorners = []
        }
        cell.contentView.viewWithTag(1001)?.removeFromSuperview()
        if indexPath.row < languages.count - 1 {
            let sep = UIView()
            sep.tag = 1001
            sep.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            sep.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(sep)
            NSLayoutConstraint.activate([
                sep.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                sep.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                sep.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                sep.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        let isSelected = selectedIndex == indexPath.row
        let radioOutlineColor = UIColor(white: 0.75, alpha: 1)
        let outerSize: CGFloat = 22
        let innerSize: CGFloat = 11
        if isSelected {
            let outer = UIView()
            outer.backgroundColor = .clear
            outer.layer.cornerRadius = outerSize / 2
            outer.layer.borderWidth = 1.5
            outer.layer.borderColor = radioOutlineColor.cgColor
            outer.frame = CGRect(x: 0, y: 0, width: outerSize, height: outerSize)
            let inner = UIView()
            inner.backgroundColor = purpleAccent
            inner.layer.cornerRadius = innerSize / 2
            inner.frame = CGRect(x: (outerSize - innerSize) / 2, y: (outerSize - innerSize) / 2, width: innerSize, height: innerSize)
            outer.addSubview(inner)
            cell.accessoryView = outer
        } else {
            let circle = UIView()
            circle.backgroundColor = .clear
            circle.layer.cornerRadius = outerSize / 2
            circle.layer.borderWidth = 1.5
            circle.layer.borderColor = radioOutlineColor.cgColor
            circle.frame = CGRect(x: 0, y: 0, width: outerSize, height: outerSize)
            cell.accessoryView = circle
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let newIndex = indexPath.row
        guard newIndex != selectedIndex else { return }
        selectedIndex = newIndex
        tableView.reloadData()
        if let window = view.window {
            AppRootTransition.reloadMainInterface(window: window)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 56 }

    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 0 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { nil }
}

final class PortfolioDemosViewController: UIViewController {

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
        if #available(iOS 15.0, *) { t.sectionHeaderTopPadding = 0 }
        return t
    }()

    private static let appCardCornerRadius: CGFloat = 5
    private static let sectionSpacing: CGFloat = 12
    private var appNames: [String] { [AppStrings.nameApp, AppStrings.nameApp, AppStrings.nameApp] }
    private let purpleAccent = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1.0)

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
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem.touchTargetBackChevron(target: self, action: #selector(backTapped))
        navigationItem.leftBarButtonItem?.tintColor = .white
        title = AppStrings.portfolioDemos
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.barTintColor = .clear
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        tableView.delegate = self
        tableView.dataSource = self
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }
}

extension PortfolioDemosViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        appNames.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = languageAndAppsCellBg
        cell.selectionStyle = .none
        cell.textLabel?.text = nil
        cell.textLabel?.isHidden = true
        cell.imageView?.image = nil
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.layer.cornerRadius = Self.appCardCornerRadius
        cell.clipsToBounds = true

        let iconPlaceholder = UIView()
        iconPlaceholder.backgroundColor = UIColor(white: 0.55, alpha: 1)
        iconPlaceholder.layer.cornerRadius = 8
        iconPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = appNames[indexPath.section]
        label.font = AppFonts.regular(17)
        label.textColor = .white
        label.fitTextWithinBounds(multiline: true)
        label.translatesAutoresizingMaskIntoConstraints = false
        let installBtn = TouchTargetButton(type: .system)
        installBtn.setTitle(AppStrings.install, for: .normal)
        installBtn.setTitleColor(.white, for: .normal)
        installBtn.titleLabel?.font = AppFonts.semibold(14)
        installBtn.fitTitleWithinBounds(maxLines: 1)
        installBtn.backgroundColor = purpleAccent
        installBtn.layer.cornerRadius = Self.appCardCornerRadius
        installBtn.translatesAutoresizingMaskIntoConstraints = false

        cell.contentView.addSubview(iconPlaceholder)
        cell.contentView.addSubview(label)
        cell.contentView.addSubview(installBtn)
        NSLayoutConstraint.activate([
            iconPlaceholder.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            iconPlaceholder.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            iconPlaceholder.widthAnchor.constraint(equalToConstant: 44),
            iconPlaceholder.heightAnchor.constraint(equalToConstant: 44),
            label.leadingAnchor.constraint(equalTo: iconPlaceholder.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: installBtn.leadingAnchor, constant: -12),
            installBtn.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            installBtn.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            installBtn.widthAnchor.constraint(equalToConstant: 80),
            installBtn.heightAnchor.constraint(equalToConstant: 36)
        ])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 64 }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 0 : Self.sectionSpacing
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { UIView() }
}
