import Foundation
import UIKit

final class LoadingPresenter: LoadingPresenterProtocol {
    weak var view: LoadingViewProtocol?
    private let displayDuration: TimeInterval = 1.5

    init(view: LoadingViewProtocol) {
        self.view = view
    }

    func viewDidLoad() {
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) { [weak self] in
            self?.view?.finishLoading()
        }
    }
}
