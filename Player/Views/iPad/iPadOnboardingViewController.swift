import UIKit

// MARK: - Временно скрыт пейволл: после третьего онбординга переход сразу в приложение, последний экран без надписей/кнопок про подписку. Чтобы вернуть: paywallHidden = false, в makePageView снова добавлять close/restore на последней странице, в updateContinueButton вернуть subtitle для последней, в continueTapped вызывать openSubscriptionOnboarding().

private struct iPadOnboardingPage {
    let highlightedTitle: String
    let remainingTitle: String
    let imageName: String
    let buttonTitle: String
    let bodyText: String
    let buttonShowsArrow: Bool
}

final class iPadOnboardingViewController: UIViewController, UIScrollViewDelegate, UITextViewDelegate {

    /// true = пейволл скрыт: с последнего экрана переход в главное меню, без надписей про подписку
    private let paywallHidden = true

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override var shouldAutorotate: Bool { false }

    private static let imageWidthFraction: CGFloat = 0.70
    private static let buttonWidthFraction: CGFloat = 0.35
    private static let buttonHeightFraction: CGFloat = 0.055
    private static let buttonCornerRadiusFraction: CGFloat = 0.25
    private static let buttonPaddingV: CGFloat = 23
    private static let buttonPaddingH: CGFloat = 77
    private static let buttonGap: CGFloat = 11

    private let pages: [iPadOnboardingPage] = [
        iPadOnboardingPage(
            highlightedTitle: AppStrings.videos,
            remainingTitle: AppStrings.forEasyViewing,
            imageName: "onboarding-1-ipad",
            buttonTitle: AppStrings.continue_,
            bodyText: AppStrings.onboardingBodyText,
            buttonShowsArrow: true
        ),
        iPadOnboardingPage(
            highlightedTitle: AppStrings.music,
            remainingTitle: AppStrings.forYourWellbeing,
            imageName: "onboarding-2-ipad",
            buttonTitle: AppStrings.continue_,
            bodyText: AppStrings.onboardingBodyText,
            buttonShowsArrow: true
        ),
        iPadOnboardingPage(
            highlightedTitle: AppStrings.playlist,
            remainingTitle: AppStrings.toBoostYourEnergy,
            imageName: "onboarding-3-ipad",
            buttonTitle: AppStrings.start3DaysForFree,
            bodyText: AppStrings.onboardingBodyText,
            buttonShowsArrow: false
        )
    ]

    private let backgroundImageView = UIImageView()
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let continueButton = iPadOnboardingGradientButton(type: .system)
    private let pageControl = UIPageControl()
    private let legalTextView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupBackground()
        setupScrollView()
        setupPages()
        setupContinueButton()
        setupPageControl()
        setupLegalLabel()
    }

    private func setupBackground() {
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

    private func makePageView(for page: iPadOnboardingPage, index: Int) -> UIView {
        let container = iPadOnboardingPageContainerView()
        container.backgroundColor = .clear

        let imageView = UIImageView()
        imageView.image = UIImage(named: page.imageName)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.textAlignment = .left
        titleLabel.fitTextWithinBounds(multiline: true)
        titleLabel.attributedText = makeTitleAttributed(highlighted: page.highlightedTitle, remaining: page.remainingTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = UILabel()
        bodyLabel.numberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.textAlignment = .left
        bodyLabel.fitTextWithinBounds(multiline: true)
        bodyLabel.attributedText = makeBodyAttributed(text: page.bodyText)
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        textStack.axis = .vertical
        textStack.spacing = 8
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        container.contentImageView = imageView
        container.titleLabel = titleLabel
        container.bodyLabel = bodyLabel

        container.addSubview(imageView)
        container.addSubview(textStack)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: Self.imageWidthFraction),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),

            textStack.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 72),
            textStack.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: imageView.trailingAnchor),
            imageView.topAnchor.constraint(greaterThanOrEqualTo: textStack.bottomAnchor, constant: 16)
        ])

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
        }

        return container
    }

    private func setupContinueButton() {
        continueButton.clipsToBounds = true
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        let widthMul = continueButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: Self.buttonWidthFraction)
        let heightMul = continueButton.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: Self.buttonHeightFraction)
        widthMul.priority = .defaultHigh
        heightMul.priority = .defaultHigh
        NSLayoutConstraint.activate([
            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            widthMul,
            heightMul,
            continueButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
        ])
        updateContinueButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        continueButton.layer.cornerRadius = continueButton.bounds.height * Self.buttonCornerRadiusFraction
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
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributed.addAttributes([.font: AppFonts.regular(12), .foregroundColor: UIColor.white.withAlphaComponent(0.8), .paragraphStyle: paragraph], range: NSRange(full.startIndex..<full.endIndex, in: full))
        if let r1 = full.range(of: termsTitle), let url = URL(string: AppStrings.termsOfUseURL) {
            attributed.addAttributes([.link: url], range: NSRange(r1, in: full))
        }
        if let r3 = full.range(of: policyTitle), let url = URL(string: AppStrings.privacyPolicyURL) {
            attributed.addAttributes([.link: url], range: NSRange(r3, in: full))
        }
        legalTextView.attributedText = attributed
        legalTextView.linkTextAttributes = [.foregroundColor: UIColor.white]
        view.addSubview(legalTextView)
        NSLayoutConstraint.activate([
            legalTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            legalTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            legalTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func makeTitleAttributed(highlighted: String, remaining: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.minimumLineHeight = 41
        paragraph.maximumLineHeight = 41
        let purple = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1)
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: highlighted + " ", attributes: [
            .font: AppFonts.bold(34),
            .foregroundColor: purple,
            .paragraphStyle: paragraph
        ]))
        result.append(NSAttributedString(string: remaining, attributes: [
            .font: AppFonts.bold(34),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]))
        return result
    }

    private func makeBodyAttributed(text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.minimumLineHeight = 16
        paragraph.maximumLineHeight = 16
        return NSAttributedString(string: text, attributes: [
            .font: AppFonts.regular(12),
            .foregroundColor: UIColor.white.withAlphaComponent(0.5),
            .paragraphStyle: paragraph
        ])
    }

    private var currentPageIndex: Int {
        let w = scrollView.bounds.width
        guard w > 0 else { return 0 }
        return Int(round(scrollView.contentOffset.x / w))
    }

    private func updateContinueButton() {
        let index = currentPageIndex
        let page = pages[index]
        let isLast = index == pages.count - 1
        let title = isLast && paywallHidden ? AppStrings.continue_ : page.buttonTitle
        let showArrow = isLast && paywallHidden ? true : page.buttonShowsArrow
        let subtitle = isLast && !paywallHidden ? AppStrings.onboardingThenPricePerWeek : nil
        continueButton.configure(title: title, showArrow: showArrow, subtitle: subtitle)
    }

    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(url)
        return false
    }

    @objc private func continueTapped() {
        let index = currentPageIndex
        if index < pages.count - 1 {
            let nextIndex = index + 1
            let offsetX = CGFloat(nextIndex) * scrollView.bounds.width
            scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
            pageControl.currentPage = nextIndex
            updateContinueButton()
        } else {
            if paywallHidden {
                openMainMenu()
            } else {
                openSubscriptionOnboarding()
            }
        }
    }

    @objc private func closeTapped() {
        showExitConfirmation()
    }

    @objc private func restoreTapped() {
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
        guard let window = view.window, let root = window.rootViewController as? iPadRootViewController else { return }
        let paywall = iPadPaywallViewController()
        paywall.isGateMode = true
        root.setChild(paywall)
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {}
    }

    private func openSubscriptionOnboarding() {
        guard let window = view.window, let root = window.rootViewController as? iPadRootViewController else { return }
        let paywall = iPadPaywallViewController()
        paywall.isGateMode = false
        root.setChild(paywall)
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {}
    }

    private func openMainMenu() {
        UserDefaults.standard.set(true, forKey: MediaStorageService.onboardingCompletedKey)
        let menu = MenuViewController()
        let nav = UINavigationController(rootViewController: menu)
        nav.navigationBar.isTranslucent = false
        nav.view.backgroundColor = .white
        guard let window = view.window, let root = window.rootViewController as? iPadRootViewController else { return }
        root.setChild(nav)
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {}
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageControl.currentPage = currentPageIndex
        updateContinueButton()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        pageControl.currentPage = currentPageIndex
        updateContinueButton()
    }
}

private final class iPadOnboardingPageContainerView: UIView {
    weak var contentImageView: UIImageView?
    weak var titleLabel: UILabel?
    weak var bodyLabel: UILabel?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let iv = contentImageView, let t = titleLabel, let b = bodyLabel else { return }
        let w = iv.bounds.width
        if w > 0 {
            if t.preferredMaxLayoutWidth != w { t.preferredMaxLayoutWidth = w; t.setNeedsLayout() }
            if b.preferredMaxLayoutWidth != w { b.preferredMaxLayoutWidth = w; b.setNeedsLayout() }
        }
    }
}

private final class iPadOnboardingGradientButton: TouchTargetButton {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [
            UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1).cgColor,
            UIColor(red: 0xA2/255, green: 0x84/255, blue: 0xF6/255, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    required init?(coder: NSCoder) { nil }

    func configure(title: String, showArrow: Bool, subtitle: String? = nil) {
        contentEdgeInsets = UIEdgeInsets(top: 23, left: 77, bottom: 23, right: 77)
        setTitle(nil, for: .normal)
        setImage(nil, for: .normal)
        subviews.forEach { $0.removeFromSuperview() }
        let stack = UIStackView()
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = title
        label.font = AppFonts.semibold(17)
        label.textColor = .white
        label.textAlignment = .center
        if let sub = subtitle, !sub.isEmpty {
            stack.axis = .vertical
            stack.spacing = 4
            stack.addArrangedSubview(label)
            let subLabel = UILabel()
            subLabel.text = sub
            subLabel.font = AppFonts.regular(12)
            subLabel.textColor = UIColor.white.withAlphaComponent(0.7)
            subLabel.textAlignment = .center
            stack.addArrangedSubview(subLabel)
        } else {
            stack.axis = .horizontal
            stack.spacing = 11
            stack.addArrangedSubview(label)
            if showArrow, let arrowImage = UIImage(named: "Arrow") {
                let arrowView = UIImageView(image: arrowImage.withRenderingMode(.alwaysTemplate))
                arrowView.tintColor = .white
                arrowView.contentMode = .scaleAspectFit
                arrowView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    arrowView.widthAnchor.constraint(equalToConstant: 14),
                    arrowView.heightAnchor.constraint(equalToConstant: 14)
                ])
                stack.addArrangedSubview(arrowView)
            }
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = layer.cornerRadius
    }
}
