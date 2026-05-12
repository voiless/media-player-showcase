import UIKit

enum AppRootTransition {
    private static var customRootHandler: ((UIWindow, UIViewController) -> Void)?

    static func setCustomRootHandler(_ handler: ((UIWindow, UIViewController) -> Void)?) {
        customRootHandler = handler
    }

    static func setRoot(window: UIWindow, viewController: UIViewController) {
        if let handler = customRootHandler {
            handler(window, viewController)
        } else {
            window.rootViewController = viewController
        }
    }

    static func reloadMainInterface(window: UIWindow) {
        let menu = MenuViewController()
        let nav = MainNavigationController(rootViewController: menu)
        nav.navigationBar.isTranslucent = false
        nav.view.backgroundColor = .white
        setRoot(window: window, viewController: nav)
        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {}
    }
}
