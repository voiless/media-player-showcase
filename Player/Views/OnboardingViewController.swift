import UIKit

// MARK: - Временно скрыт пейволл: после третьего онбординга переход сразу в приложение, последний экран без надписей/кнопок про подписку. Чтобы вернуть: paywallHidden = false, последнюю страницу вернуть на start3DaysForFree/стрелку false, раскомментировать кнопки закрытия/восстановления и вызов openSubscriptionOnboarding().

private struct OnboardingPage {
    let highlightedTitle: String
    let remainingTitle: String
    let imageName: String
    let buttonTitle: String
    let bodyText: String
    let buttonShowsArrow: Bool
}

final class OnboardingViewController: UIViewController, UIScrollViewDelegate, UITextViewDelegate {

    /// true = пейволл скрыт: с последнего экрана переход в главное меню, без надписей про подписку
    private let paywallHidden = true

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override var shouldAutorotate: Bool { false }

    static func shouldShowOnboarding() -> Bool {
        guard !AppConfig.onboardingDisabled else { return false }
        return !UserDefaults.standard.bool(forKey: MediaStorageService.onboardingCompletedKey)
    }


    private let backgroundImageView = UIImageView()
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let pageControl = UIPageControl()
    private let legalTextView = UITextView()


    private let pages: [OnboardingPage] = [
        OnboardingPage(
            highlightedTitle: AppStrings.videos,
            remainingTitle: AppStrings.forEasyViewing,
            imageName: "Frame1",
            buttonTitle: AppStrings.continue_,
            bodyText: AppStrings.onboardingBodyText,
            buttonShowsArrow: true
        ),
        OnboardingPage(
            highlightedTitle: AppStrings.music,
            remainingTitle: AppStrings.forYourWellbeing,
            imageName: "Frame2",
            buttonTitle: AppStrings.continue_,
            bodyText: AppStrings.onboardingBodyText,
            buttonShowsArrow: true
        ),
        OnboardingPage(
            highlightedTitle: AppStrings.playlist,
            remainingTitle: AppStrings.toBoostYourEnergy,
            imageName: "Frame3",
            buttonTitle: AppStrings.start3DaysForFree,
            bodyText: AppStrings.onboardingBodyText,
            buttonShowsArrow: false
        )
    ]


    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupScrollView()
        setupPages()
        setupPageControl()
        setupLegalLabel()
    }


    private func setupBackground() {
        view.backgroundColor = .black

        backgroundImageView.image = UIImage(named: "onboarding-background")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(backgroundImageView)

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        backgroundImageView.isUserInteractionEnabled = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    private func setupScrollView() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentView.axis = .horizontal
        contentView.distribution = .fill
        contentView.alignment = .fill
        contentView.backgroundColor = .clear
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.frameLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.frameLayoutGuide.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    private func setupPages() {
        for (index, page) in pages.enumerated() {
            let pageView = makePageView(for: page, index: index)
            contentView.addArrangedSubview(pageView)
            pageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        }
    }

    private func setupPageControl() {
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.3)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.isUserInteractionEnabled = false

        view.addSubview(pageControl)

        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])
    }

    private func setupLegalLabel() {
        legalTextView.isEditable = false
        legalTextView.isScrollEnabled = false
        legalTextView.backgroundColor = .clear
        legalTextView.textContainerInset = .zero
        legalTextView.textContainer.lineFragmentPadding = 0
        legalTextView.delegate = self
        legalTextView.translatesAutoresizingMaskIntoConstraints = false

        let termsTitle = AppStrings.termsOfUse
        let andText = AppStrings.and
        let policyTitle = AppStrings.privacyPolicy
        let full = termsTitle + andText + policyTitle
        let attributed = NSMutableAttributedString(string: full)
        let white = UIColor.white
        let mediumGray = UIColor(white: 0.6, alpha: 1.0)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributed.addAttributes([.font: AppFonts.regular(12), .paragraphStyle: paragraph], range: NSRange(full.startIndex..<full.endIndex, in: full))
        if let r1 = full.range(of: termsTitle), let url = URL(string: AppStrings.termsOfUseURL) {
            attributed.addAttributes([.foregroundColor: white, .link: url], range: NSRange(r1, in: full))
        }
        if let r2 = full.range(of: andText) {
            attributed.addAttributes([.foregroundColor: mediumGray], range: NSRange(r2, in: full))
        }
        if let r3 = full.range(of: policyTitle), let url = URL(string: AppStrings.privacyPolicyURL) {
            attributed.addAttributes([.foregroundColor: white, .link: url], range: NSRange(r3, in: full))
        }
        legalTextView.attributedText = attributed
        legalTextView.linkTextAttributes = [.foregroundColor: white, .underlineStyle: 0]

        view.addSubview(legalTextView)

        NSLayoutConstraint.activate([
            legalTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            legalTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            legalTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(url)
        return false
    }


    private func makePageView(for page: OnboardingPage, index: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.textAlignment = .left
        titleLabel.fitTextWithinBounds(multiline: true)
        titleLabel.attributedText = makeTitleAttributedString(
            highlighted: page.highlightedTitle,
            remaining: page.remainingTitle
        )
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.preferredMaxLayoutWidth = 327
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let bodyLabel = UILabel()
        bodyLabel.numberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.textAlignment = .left
        bodyLabel.fitTextWithinBounds(multiline: true)
        bodyLabel.attributedText = makeBodyAttributedString(text: page.bodyText)
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.preferredMaxLayoutWidth = 327
        bodyLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let imageContainer = UIView()
        imageContainer.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView()
        imageView.image = UIImage(named: page.imageName)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        imageContainer.addSubview(imageView)

        let button = GradientButton(type: .system)
        let isLast = index == pages.count - 1
        let buttonTitle = isLast && paywallHidden ? AppStrings.continue_ : page.buttonTitle
        let showArrow = isLast && paywallHidden ? true : page.buttonShowsArrow
        let subtitleText = isLast && !paywallHidden ? AppStrings.onboardingThenPricePerWeek : nil
        configureButtonContent(button, title: buttonTitle, showArrow: showArrow, subtitle: subtitleText)
        button.layer.cornerRadius = 15
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tag = index
        button.addTarget(self, action: #selector(continueButtonTapped(_:)), for: .touchUpInside)

        container.addSubview(titleLabel)
        container.addSubview(bodyLabel)
        container.addSubview(imageContainer)
        container.addSubview(button)

        var titleTopAnchor: NSLayoutYAxisAnchor = container.safeAreaLayoutGuide.topAnchor
        var titleTopConstant: CGFloat = 24

        if index == pages.count - 1 && !paywallHidden {
            let closeButton = TouchTargetButton(type: .system)
            closeButton.setTitle(AppStrings.closeSymbol, for: .normal)
            closeButton.setTitleColor(.white, for: .normal)
            closeButton.titleLabel?.font = AppFonts.semibold(20)
            closeButton.fitTitleWithinBounds(maxLines: 1)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

            let restoreButton = TouchTargetButton(type: .system)
            restoreButton.setTitle(AppStrings.restore, for: .normal)
            restoreButton.setTitleColor(.white, for: .normal)
            restoreButton.titleLabel?.font = AppFonts.semibold(15)
            restoreButton.fitTitleWithinBounds(maxLines: 1)
            restoreButton.translatesAutoresizingMaskIntoConstraints = false
            restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

            container.addSubview(closeButton)
            container.addSubview(restoreButton)

            NSLayoutConstraint.activate([
                closeButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
                closeButton.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 16),

                restoreButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
                restoreButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor)
            ])

            titleTopAnchor = closeButton.bottomAnchor
            titleTopConstant = 16
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: titleTopAnchor, constant: titleTopConstant),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            bodyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),

            imageContainer.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 24),
            imageContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageContainer.bottomAnchor.constraint(equalTo: button.topAnchor, constant: -24),

            imageView.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 339),
            imageView.heightAnchor.constraint(equalToConstant: 339),

            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            button.heightAnchor.constraint(equalToConstant: 60),
            button.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])

        return container
    }

    private func makeTitleAttributedString(highlighted: String, remaining: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 41
        paragraph.maximumLineHeight = 41

        let highlightedAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFonts.bold(34),
            .foregroundColor: UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1.0),
            .kern: 0.4,
            .paragraphStyle: paragraph
        ]

        let remainingAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFonts.bold(34),
            .foregroundColor: UIColor.white,
            .kern: 0.4,
            .paragraphStyle: paragraph
        ]

        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: highlighted + " ", attributes: highlightedAttributes))
        result.append(NSAttributedString(string: remaining, attributes: remainingAttributes))
        return result
    }

    private func makeBodyAttributedString(text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 16
        paragraph.maximumLineHeight = 16
        let attrs: [NSAttributedString.Key: Any] = [
            .font: AppFonts.regular(12),
            .foregroundColor: UIColor.white.withAlphaComponent(0.5),
            .paragraphStyle: paragraph
        ]
        return NSAttributedString(string: text, attributes: attrs)
    }

    private func configureButtonContent(_ button: GradientButton, title: String, showArrow: Bool, subtitle: String? = nil) {
        button.setTitle(nil, for: .normal)
        button.setImage(nil, for: .normal)
        let stack = UIStackView()
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFonts.semibold(17)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.fitTextWithinBounds(multiline: true)
        if let sub = subtitle, !sub.isEmpty {
            stack.axis = .vertical
            stack.spacing = 4
            stack.addArrangedSubview(titleLabel)
            let subLabel = UILabel()
            subLabel.text = sub
            subLabel.font = AppFonts.regular(12)
            subLabel.textColor = UIColor.white.withAlphaComponent(0.7)
            subLabel.textAlignment = .center
            subLabel.fitTextWithinBounds(multiline: true)
            stack.addArrangedSubview(subLabel)
        } else if showArrow, let arrowImage = UIImage(named: "Arrow") {
            stack.axis = .horizontal
            stack.spacing = 8
            stack.addArrangedSubview(titleLabel)
            let arrowView = UIImageView(image: arrowImage.withRenderingMode(.alwaysTemplate))
            arrowView.tintColor = .white
            arrowView.contentMode = .scaleAspectFit
            arrowView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                arrowView.widthAnchor.constraint(equalToConstant: 14),
                arrowView.heightAnchor.constraint(equalToConstant: 14)
            ])
            stack.addArrangedSubview(arrowView)
        } else {
            stack.axis = .horizontal
            stack.addArrangedSubview(titleLabel)
        }
        button.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }

    @objc
    private func continueButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        if index < pages.count - 1 {
            let nextIndex = index + 1
            let offsetX = CGFloat(nextIndex) * scrollView.bounds.width
            scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
            pageControl.currentPage = nextIndex
        } else {
            if paywallHidden {
                openMainMenu()
            } else {
                openSubscriptionOnboarding()
            }
        }
    }

    @objc
    private func closeTapped() {
        showExitConfirmation()
    }

    @objc
    private func restoreTapped() {
        SubscriptionStore.shared.restorePurchases { [weak self] success in
            guard let self = self else { return }
            if success { self.openMainMenu() }
        }
    }

    private func showExitConfirmation() {
        let alert = DarkConfirmViewController()
        alert.titleText = AppStrings.exitAppConfirmTitle
        alert.messageText = AppStrings.exitAppConfirmMessage
        alert.deleteTitle = AppStrings.exit
        alert.singleButtonMode = false
        alert.onDelete = { exit(0) }
        alert.onCancel = { }
        alert.modalPresentationStyle = .overFullScreen
        alert.modalTransitionStyle = .crossDissolve
        present(alert, animated: true)
    }

    private func openPaywallAsGate() {
        guard let window = view.window else { return }
        PaywallViewController.isGateModeForReplacement = true
        let paywall = PaywallViewController()
        paywall.isGateMode = true
        AppRootTransition.setRoot(window: window, viewController: paywall)
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {}
    }

    private func openSubscriptionOnboarding() {
        guard let window = view.window else { return }
        let paywall = PaywallViewController()
        paywall.isGateMode = false
        AppRootTransition.setRoot(window: window, viewController: paywall)
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {}
    }

    private func openMainMenu() {
        UserDefaults.standard.set(true, forKey: MediaStorageService.onboardingCompletedKey)
        let menu = MenuViewController()
        let nav = MainNavigationController(rootViewController: menu)
        nav.navigationBar.isTranslucent = false
        nav.view.backgroundColor = .white
        guard let window = view.window else { return }
        AppRootTransition.setRoot(window: window, viewController: nav)
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {}
    }


    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        pageControl.currentPage = page
    }
}



private final class GradientButton: TouchTargetButton {

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }

    private func setupGradient() {
        gradientLayer.colors = [
            UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1.0).cgColor,
            UIColor(red: 0xA2/255, green: 0x84/255, blue: 0xF6/255, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
