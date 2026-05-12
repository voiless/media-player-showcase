import UIKit

final class LoadingViewController: UIViewController, LoadingViewProtocol {

    var presenter: LoadingPresenterProtocol?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override var shouldAutorotate: Bool { false }

    private let backgroundImageView = UIImageView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let loaderImageView = UIImageView()
    private var iconTopConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startLoaderAnimation()
        presenter?.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if traitCollection.userInterfaceIdiom == .phone, #available(iOS 16.0, *), let windowScene = view.window?.windowScene {
            setNeedsUpdateOfSupportedInterfaceOrientations()
            let geometry = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            windowScene.requestGeometryUpdate(geometry) { _ in }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let height = view.bounds.height > 0 ? view.bounds.height : UIScreen.main.bounds.height
        iconTopConstraint?.constant = AppConfig.loadingLogoTopInset(forHeight: height)
    }

    private func setupUI() {
        view.backgroundColor = .black

        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.image = UIImage(named: "load_back")
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)

        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layer.cornerRadius = 15
        iconImageView.image = UIImage(named: "icon_player")
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconImageView)

        titleLabel.text = AppStrings.loadingScreenTitle
        titleLabel.font = AppFonts.semibold(20)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.fitTextWithinBounds(multiline: true)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        loaderImageView.contentMode = .scaleAspectFit
        loaderImageView.image = UIImage(named: "loader")
        loaderImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loaderImageView)

        let height = view.bounds.height > 0 ? view.bounds.height : UIScreen.main.bounds.height
        iconTopConstraint = iconImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: AppConfig.loadingLogoTopInset(forHeight: height))

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconTopConstraint!,
            iconImageView.widthAnchor.constraint(equalToConstant: 87),
            iconImageView.heightAnchor.constraint(equalToConstant: 87),
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            loaderImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loaderImageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90),
            loaderImageView.widthAnchor.constraint(equalToConstant: 54),
            loaderImageView.heightAnchor.constraint(equalToConstant: 54)
        ])
    }

    private func startLoaderAnimation() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * CGFloat.pi
        rotation.duration = 0.5
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        loaderImageView.layer.add(rotation, forKey: "rotation")
    }

    func finishLoading() {
        guard let window = view.window else { return }

        if AppConfig.onboardingDisabled {
            UserDefaults.standard.set(true, forKey: MediaStorageService.onboardingCompletedKey)
        }

        guard !OnboardingViewController.shouldShowOnboarding() else {
            if #available(iOS 16.0, *), let scene = window.windowScene {
                let geometry = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
                scene.requestGeometryUpdate(geometry) { _ in }
            }
            let onboarding = OnboardingViewController()
            AppRootTransition.setRoot(window: window, viewController: onboarding)
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {}
            return
        }

        let menu = MenuViewController()
        let nav = MainNavigationController(rootViewController: menu)
        nav.navigationBar.isTranslucent = false
        nav.view.backgroundColor = .white
        AppRootTransition.setRoot(window: window, viewController: nav)
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {}
    }
}
