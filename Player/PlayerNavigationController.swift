import UIKit

final class PlayerNavigationController: UINavigationController {

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if AppOrientationState.isPictureInPictureActive, traitCollection.userInterfaceIdiom == .phone {
            return [.portrait, .landscapeLeft, .landscapeRight]
        }
        return topViewController?.supportedInterfaceOrientations ?? .portrait
    }

    override var shouldAutorotate: Bool {
        if AppOrientationState.isPictureInPictureActive { return true }
        return false
    }
}
