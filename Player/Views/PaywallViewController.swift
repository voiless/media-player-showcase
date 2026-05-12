import StoreKit
import UIKit

final class PaywallViewController: UIViewController, UITextViewDelegate {


    var isGateMode: Bool = false
    static var isGateModeForReplacement: Bool = false

    private enum Layout {
        static let imageSize: CGFloat = 307
        static let titleWidth: CGFloat = 346
        static let buttonWidth: CGFloat = 339
        static let optionButtonHeight: CGFloat = 65
        static let mainButtonHeight: CGFloat = 60
        static let cornerRadius: CGFloat = 15
        static let mainButtonPaddingTop: CGFloat = 23
        static let mainButtonPaddingBottom: CGFloat = 23
        static let mainButtonPaddingHorizontal: CGFloat = 77
    }

    private var freeTrialEnabled = true
    private var selectedProductId: String = SubscriptionProductId.yearly
    private var productInfos: [SubscriptionProductInfo] = []
    private let store = SubscriptionStore.shared
    private var blackPanelTopConstraint: NSLayoutConstraint?
    private var blackPanelHeightConstraint: NSLayoutConstraint?

    private static let refHeightiPhone: CGFloat = 812
    private static let panelTopRatioiPhone: CGFloat = 301 / refHeightiPhone
    private static let panelHeightRatioiPhone: CGFloat = 519 / refHeightiPhone

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
        b.setTitleColor(PaywallViewController.topButtonsColor, for: .normal)
        b.titleLabel?.font = AppFonts.semibold(20)
        b.fitTitleWithinBounds(maxLines: 1)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let restoreButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.setTitle(AppStrings.restore, for: .normal)
        b.setTitleColor(PaywallViewController.topButtonsColor, for: .normal)
        b.titleLabel?.font = AppFonts.semibold(15)
        b.fitTitleWithinBounds(maxLines: 1)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
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
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        view.addSubview(closeButton)
        view.addSubview(restoreButton)
        scrollView.addSubview(contentStack)
        bestOfferBadge.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(bestOfferBadge)

        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        heroImageView.image = UIImage(named: "onboarding-premium")
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.clipsToBounds = true
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(heroImageView)

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
        contentStack.addArrangedSubview(titleLabel)

        subtitleLabel.text = AppStrings.fullAccessToAllFunctions
        subtitleLabel.font = AppFonts.regular(14)
        subtitleLabel.textColor = .white
        subtitleLabel.textAlignment = .center
        subtitleLabel.fitTextWithinBounds(multiline: true, preferredMaxLayoutWidth: Layout.buttonWidth)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(subtitleLabel)

        let toggleRow = UIView()
        toggleRow.translatesAutoresizingMaskIntoConstraints = false
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
        toggleRow.addSubview(toggleLabel)
        toggleRow.addSubview(trialSwitch)
        contentStack.addArrangedSubview(toggleRow)

        yearlyCard.translatesAutoresizingMaskIntoConstraints = false
        weeklyCard.translatesAutoresizingMaskIntoConstraints = false
        yearlyCard.addTarget(self, action: #selector(selectYearly), for: .touchUpInside)
        weeklyCard.addTarget(self, action: #selector(selectWeekly), for: .touchUpInside)
        contentStack.addArrangedSubview(yearlyCard)
        contentStack.addArrangedSubview(weeklyCard)

        mainButton.layer.cornerRadius = Layout.cornerRadius
        mainButton.backgroundColor = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1)
        mainButton.setTitleColor(.white, for: .normal)
        mainButton.titleLabel?.font = AppFonts.semibold(17)
        mainButton.fitTitleWithinBounds(maxLines: 2)
        mainButton.contentEdgeInsets = UIEdgeInsets(top: Layout.mainButtonPaddingTop, left: Layout.mainButtonPaddingHorizontal, bottom: Layout.mainButtonPaddingBottom, right: Layout.mainButtonPaddingHorizontal)
        mainButton.translatesAutoresizingMaskIntoConstraints = false
        mainButton.addTarget(self, action: #selector(mainButtonTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(mainButton)

        setupTermsTextView()
        contentStack.addArrangedSubview(termsTextView)

        contentStack.setCustomSpacing(24, after: heroImageView)
        contentStack.setCustomSpacing(8, after: titleLabel)
        contentStack.setCustomSpacing(24, after: subtitleLabel)
        contentStack.setCustomSpacing(20, after: toggleRow)
        contentStack.setCustomSpacing(12, after: yearlyCard)
        contentStack.setCustomSpacing(24, after: weeklyCard)
        contentStack.setCustomSpacing(16, after: mainButton)

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        if isGateMode {
            closeButton.isHidden = true
        }

        updateMainButtonTitle()
        updateSelection()

        blackPanel.layer.cornerRadius = 55
        blackPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let panelTop = blackPanel.topAnchor.constraint(equalTo: view.topAnchor, constant: 301)
        let panelHeight = blackPanel.heightAnchor.constraint(equalToConstant: 519)
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
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            restoreButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            restoreButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 80),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            bestOfferBadge.centerXAnchor.constraint(equalTo: contentStack.centerXAnchor),
            bestOfferBadge.bottomAnchor.constraint(equalTo: yearlyCard.topAnchor, constant: 11),
            bestOfferBadge.widthAnchor.constraint(equalToConstant: BestOfferBadgeView.intrinsicSize.width),
            bestOfferBadge.heightAnchor.constraint(equalToConstant: BestOfferBadgeView.intrinsicSize.height),
            heroImageView.widthAnchor.constraint(equalToConstant: Layout.imageSize),
            heroImageView.heightAnchor.constraint(equalToConstant: Layout.imageSize),
            titleLabel.widthAnchor.constraint(equalToConstant: Layout.titleWidth),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.buttonWidth),
            toggleRow.heightAnchor.constraint(equalToConstant: 32),
            toggleRow.widthAnchor.constraint(equalToConstant: Layout.buttonWidth),
            toggleLabel.leadingAnchor.constraint(equalTo: toggleRow.leadingAnchor),
            toggleLabel.centerYAnchor.constraint(equalTo: toggleRow.centerYAnchor),
            toggleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trialSwitch.leadingAnchor, constant: -12),
            trialSwitch.trailingAnchor.constraint(equalTo: toggleRow.trailingAnchor),
            trialSwitch.centerYAnchor.constraint(equalTo: toggleRow.centerYAnchor),
            yearlyCard.widthAnchor.constraint(equalToConstant: Layout.buttonWidth),
            yearlyCard.heightAnchor.constraint(equalToConstant: Layout.optionButtonHeight),
            weeklyCard.widthAnchor.constraint(equalToConstant: Layout.buttonWidth),
            weeklyCard.heightAnchor.constraint(equalToConstant: Layout.optionButtonHeight),
            mainButton.widthAnchor.constraint(equalToConstant: Layout.buttonWidth),
            mainButton.heightAnchor.constraint(equalToConstant: Layout.mainButtonHeight),
            termsTextView.widthAnchor.constraint(equalToConstant: Layout.buttonWidth)
        ])

        store.loadProducts { [weak self] infos in
            self?.productInfos = infos
            self?.reloadProductCards()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let h = view.bounds.height
        blackPanelTopConstraint?.constant = h * Self.panelTopRatioiPhone
        blackPanelHeightConstraint?.constant = h * Self.panelHeightRatioiPhone
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
        AppRootTransition.setRoot(window: window, viewController: nav)
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {}
    }
}
