import UIKit

enum AppOrientationState {
    private static let lock = NSLock()
    private static var _pipActive = false

    static var isPictureInPictureActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _pipActive
    }

    static func setPictureInPictureActive(_ active: Bool) {
        lock.lock()
        _pipActive = active
        lock.unlock()
        DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .forEach { scene in
                        scene.windows.forEach { window in
                            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                            window.rootViewController?.children.forEach { $0.setNeedsUpdateOfSupportedInterfaceOrientations() }
                        }
                    }
            } else {
                UIViewController.attemptRotationToDeviceOrientation()
            }
        }
    }

    static func requestPortraitPhone(_ scene: UIWindowScene?) {
        guard let scene = scene, scene.traitCollection.userInterfaceIdiom == .phone else { return }
        if #available(iOS 16.0, *) {
            let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            scene.requestGeometryUpdate(prefs) { _ in }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
    }
}
