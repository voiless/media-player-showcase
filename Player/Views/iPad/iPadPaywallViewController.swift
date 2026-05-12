import StoreKit
import UIKit

final class iPadPaywallViewController: UIViewController, UITextViewDelegate {

    var isGateMode: Bool = false

    private enum Layout {
        static let imageWidthFraction: CGFloat = 0.70
        static let titleWidth: CGFloat = 346
        static let buttonWidth: CGFloat = 339
        static let optionButtonHeight: CGFloat = 65
        static let mainButtonHeight: CGFloat = 60
        static let cornerRadius: CGFloat = 15
        static let mainButtonPaddingTop: CGFloat = 23
        static let mainButtonPaddingBottom: CGFloat = 23
        static let mainButtonPaddingHorizontal: CGFloat = 77
    }

    private static let refHeightiPad: CGFloat = 1366
    private static let panelTopRatioiPad: CGFloat = 667 / refHeightiPad
    private static let panelHeightRatioiPad: CGFloat = 699 / refHeightiPad

    private var freeTrialEnabled = true
    private var selectedProductId: String = SubscriptionProductId.yearly
    private var productInfos: [SubscriptionProductInfo] = []
    private let store = SubscriptionStore.shared
    private var blackPanelTopConstraint: NSLayoutConstraint?
    private var blackPanelHeightConstraint: NSLayoutConstraint?

    private let backgroundImageView: UIImageView = {
        let v = UIImageView()
        v.image = UIImage(named: "load_back")
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let blackPanel: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0x07/255, green: 0x03/255, blue: 0x0A/255, alpha: 1)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private static let topButtonsColor = UIColor.white.withAlphaComponent(0.5)

    private let closeButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.setTitle(AppStrings.closeSymbol, for: .normal)
        b.setTitleColor(iPadPaywallViewController.topButtonsColor, for: .normal)
        b.titleLabel?.font = AppFonts.semibold(20)
        b.fitTitleWithinBounds(maxLines: 1)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let restoreButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.setTitle(AppStrings.restore, for: .normal)
        b.setTitleColor(iPadPaywallViewController.topButtonsColor, for: .normal)
        b.titleLabel?.font = AppFonts.semibold(15)
        b.fitTitleWithinBounds(maxLines: 1)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let contentContainer = UIView()
    private let heroImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let toggleLabel = UILabel()
    private let trialSwitch = UISwitch()
    private let bestOfferBadge = BestOfferBadgeView()
    private let yearlyCard = PaywallOptionCard()
    private let weeklyCard = PaywallOptionCard()
    private let mainButton = TouchTargetButton(type: .system)
    private let termsTextView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(backgroundImageView)
        view.addSubview(blackPanel)
        view.addSubview(closeButton)
        view.addSubview(restoreButton)
        view.addSubview(contentContainer)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.image = UIImage(named: "onboarding-premium")
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.clipsToBounds = true
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(heroImageView)

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.minimumLineHeight = 34
        titleParagraph.maximumLineHeight = 34
        titleParagraph.alignment = .center
        titleLabel.attributedText = NSAttributedString(
            string: AppStrings.getPremiumAccess,
            attributes: [
                .font: AppFonts.bold(28),
                .foregroundColor: UIColor.white,
                .paragraphStyle: titleParagraph,
                .kern: 0.38
            ]
        )
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.preferredMaxLayoutWidth = Layout.titleWidth
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(titleLabel)

        subtitleLabel.text = AppStrings.fullAccessToAllFunctions
        subtitleLabel.font = AppFonts.regular(14)
        subtitleLabel.textColor = .white
        subtitleLabel.textAlignment = .center
        subtitleLabel.fitTextWithinBounds(multiline: true, preferredMaxLayoutWidth: Layout.buttonWidth)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(subtitleLabel)

        toggleLabel.text = AppStrings.freeTrialEnabled
        toggleLabel.font = AppFonts.regular(17)
        toggleLabel.textColor = .white
        toggleLabel.fitTextWithinBounds(multiline: false)
        toggleLabel.translatesAutoresizingMaskIntoConstraints = false
        toggleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trialSwitch.isOn = freeTrialEnabled
        trialSwitch.onTintColor = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1)
        trialSwitch.translatesAutoresizingMaskIntoConstraints = false
        trialSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        contentContainer.addSubview(toggleLabel)
        contentContainer.addSubview(trialSwitch)

        yearlyCard.translatesAutoresizingMaskIntoConstraints = false
        weeklyCard.translatesAutoresizingMaskIntoConstraints = false
        yearlyCard.addTarget(self, action: #selector(selectYearly), for: .touchUpInside)
        weeklyCard.addTarget(self, action: #selector(selectWeekly), for: .touchUpInside)
        contentContainer.addSubview(yearlyCard)
        contentContainer.addSubview(weeklyCard)
        bestOfferBadge.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(bestOfferBadge)

        mainButton.layer.cornerRadius = Layout.cornerRadius
        mainButton.backgroundColor = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1)
        mainButton.setTitleColor(.white, for: .normal)
        mainButton.titleLabel?.font = AppFonts.semibold(17)
        mainButton.fitTitleWithinBounds(maxLines: 2)
        mainButton.contentEdgeInsets = UIEdgeInsets(top: Layout.mainButtonPaddingTop, left: Layout.mainButtonPaddingHorizontal, bottom: Layout.mainButtonPaddingBottom, right: Layout.mainButtonPaddingHorizontal)
        mainButton.translatesAutoresizingMaskIntoConstraints = false
        mainButton.addTarget(self, action: #selector(mainButtonTapped), for: .touchUpInside)
        contentContainer.addSubview(mainButton)

        setupTermsTextView()
        contentContainer.addSubview(termsTextView)

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        if isGateMode {
            closeButton.isHidden = true
        }

        updateMainButtonTitle()
        updateSelection()

        blackPanel.layer.cornerRadius = 55
        blackPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let panelTop = blackPanel.topAnchor.constraint(equalTo: view.topAnchor, constant: 667)
        let panelHeight = blackPanel.heightAnchor.constraint(equalToConstant: 699)
        blackPanelTopConstraint = panelTop
        blackPanelHeightConstraint = panelHeight

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panelTop,
            panelHeight,
            blackPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blackPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            restoreButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            restoreButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            contentContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor),
            heroImageView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            heroImageView.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            heroImageView.widthAnchor.constraint(equalTo: contentContainer.widthAnchor, multiplier: Layout.imageWidthFraction),
            heroImageView.heightAnchor.constraint(equalTo: heroImageView.widthAnchor),
            titleLabel.topAnchor.constraint(equalTo: heroImageView.bottomAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: Layout.titleWidth),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.buttonWidth),
            toggleLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            toggleLabel.leadingAnchor.constraint(equalTo: yearlyCard.leadingAnchor),
            toggleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trialSwitch.leadingAnchor, constant: -12),
            trialSwitch.centerYAnchor.constraint(equalTo: toggleLabel.centerYAnchor),
            trialSwitch.trailingAnchor.constraint(equalTo: yearlyCard.trailingAnchor),
            bestOfferBadge.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            bestOfferBadge.bottomAnchor.constraint(equalTo: yearlyCard.topAnchor, constant: 11),
            bestOfferBadge.widthAnchor.constraint(equalToConstant: BestOfferBadgeView.intrinsicSize.width),
            bestOfferBadge.heightAnchor.constraint(equalToConstant: BestOfferBadgeView.intrinsicSize.height),
            yearlyCard.topAnchor.constraint(equalTo: toggleLabel.bottomAnchor, constant: 16),
            yearlyCard.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            yearlyCard.widthAnchor.constraint(equalToConstant: Layout.buttonWidth),
            yearlyCard.heightAnchor.constraint(equalToConstant: Layout.optionButtonHeight),
            weeklyCard.topAnchor.constraint(equalTo: yearlyCard.bottomAnchor, constant: 12),
            weeklyCard.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            weeklyCard.widthAnchor.constraint(equalToConstant: Layout.buttonWidth),
            weeklyCard.heightAnchor.constraint(equalToConstant: Layout.optionButtonHeight),
            mainButton.topAnchor.constraint(equalTo: weeklyCard.bottomAnchor, constant: 20),
            mainButton.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            mainButton.widthAnchor.constraint(equalToConstant: Layout.buttonWidth),
            mainButton.heightAnchor.constraint(equalToConstant: Layout.mainButtonHeight),
            termsTextView.topAnchor.constraint(equalTo: mainButton.bottomAnchor, constant: 16),
            termsTextView.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            termsTextView.widthAnchor.constraint(equalToConstant: Layout.buttonWidth),
            termsTextView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])

        store.loadProducts { [weak self] infos in
            self?.productInfos = infos
            self?.reloadProductCards()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let h = view.bounds.height
        blackPanelTopConstraint?.constant = h * Self.panelTopRatioiPad
        blackPanelHeightConstraint?.constant = h * Self.panelHeightRatioiPad
        let buttonTitleMaxW = Layout.buttonWidth - 2 * Layout.mainButtonPaddingHorizontal
        if buttonTitleMaxW > 0 {
            mainButton.titleLabel?.preferredMaxLayoutWidth = buttonTitleMaxW
        }
    }

    private static var termsOfUseURL: URL? { URL(string: AppStrings.termsOfUseURL) }
    private static var privacyPolicyURL: URL? { URL(string: AppStrings.privacyPolicyURL) }

    private func setupTermsTextView() {
        termsTextView.isEditable = false
        termsTextView.isScrollEnabled = false
        termsTextView.backgroundColor = .clear
        termsTextView.textContainerInset = .zero
        termsTextView.textContainer.lineFragmentPadding = 0
        termsTextView.translatesAutoresizingMaskIntoConstraints = false
        let termsTitle = AppStrings.termsOfUse
        let andText = AppStrings.and
        let policyTitle = AppStrings.privacyPolicy
        let full = termsTitle + andText + policyTitle
        let attributed = NSMutableAttributedString(string: full)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributed.addAttributes([.font: AppFonts.regular(12), .foregroundColor: UIColor.white, .paragraphStyle: paragraph], range: NSRange(full.startIndex..<full.endIndex, in: full))
        if let r1 = full.range(of: termsTitle), let url = Self.termsOfUseURL {
            attributed.addAttributes([.link: url], range: NSRange(r1, in: full))
        }
        if let r2 = full.range(of: andText) {
            attributed.addAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.5)], range: NSRange(r2, in: full))
        }
        if let r3 = full.range(of: policyTitle), let url = Self.privacyPolicyURL {
            attributed.addAttributes([.link: url], range: NSRange(r3, in: full))
        }
        termsTextView.attributedText = attributed
        termsTextView.linkTextAttributes = [.foregroundColor: UIColor.white, .underlineStyle: 0]
        termsTextView.delegate = self
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL)
        return false
    }

    private func reloadProductCards() {
        for info in productInfos {
            if info.productId == SubscriptionProductId.yearly {
                yearlyCard.configure(title: info.title, price: info.price + AppStrings.perYear, badge: nil, selected: selectedProductId == info.productId)
            } else if info.productId == SubscriptionProductId.weekly {
                weeklyCard.configure(title: info.title, price: info.price + AppStrings.perWeek, badge: nil, selected: selectedProductId == info.productId)
            }
        }
        if productInfos.isEmpty {
            yearlyCard.configure(title: AppStrings.yearly, price: AppStrings.defaultYearlyPrice + AppStrings.perYear, badge: nil, selected: selectedProductId == SubscriptionProductId.yearly)
            weeklyCard.configure(title: AppStrings.weekly, price: AppStrings.defaultWeeklyPrice + AppStrings.perWeek, badge: nil, selected: selectedProductId == SubscriptionProductId.weekly)
        }
    }

    private func updateMainButtonTitle() {
        mainButton.setTitle(freeTrialEnabled ? AppStrings.startTryFreeTrial : AppStrings.continue_, for: .normal)
    }

    private func updateSelection() {
        yearlyCard.setSelected(selectedProductId == SubscriptionProductId.yearly)
        weeklyCard.setSelected(selectedProductId == SubscriptionProductId.weekly)
    }

    @objc private func toggleChanged() {
        freeTrialEnabled = trialSwitch.isOn
        updateMainButtonTitle()
    }

    @objc private func selectYearly() {
        selectedProductId = SubscriptionProductId.yearly
        updateSelection()
        updateMainButtonTitle()
    }

    @objc private func selectWeekly() {
        selectedProductId = SubscriptionProductId.weekly
        updateSelection()
        updateMainButtonTitle()
    }

    @objc private func mainButtonTapped() {
        store.purchase(productId: selectedProductId) { [weak self] success in
            guard let self = self else { return }
            if success {
                self.store.setSubscriptionPurchasedWithoutTrial(!self.freeTrialEnabled)
                self.transitionToMainApp()
            }
        }
    }

    @objc private func closeTapped() {
        if isGateMode {
            dismiss(animated: true)
        } else {
            transitionToMainApp()
        }
    }

    @objc private func restoreTapped() {
        store.restorePurchases { [weak self] success in
            guard let self = self else { return }
            if success {
                self.transitionToMainApp()
            }
        }
    }

    private func transitionToMainApp() {
        guard let window = view.window else { return }
        UserDefaults.standard.set(true, forKey: MediaStorageService.onboardingCompletedKey)
        let menu = MenuViewController()
        let nav = UINavigationController(rootViewController: menu)
        nav.navigationBar.isTranslucent = false
        nav.view.backgroundColor = .white
        if let root = window.rootViewController as? iPadRootViewController {
            root.setChild(nav)
        } else {
            AppRootTransition.setRoot(window: window, viewController: nav)
        }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {}
    }
}
