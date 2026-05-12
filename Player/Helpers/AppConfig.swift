import Foundation
import UIKit

enum AppConfig {

    static let appStoreId = "0"
    static let onboardingDisabled = true

    static var appStoreURL: URL? { nil }

    static var appStoreReviewURL: URL? { nil }

    static func adaptiveHeightProgress(forHeight height: CGFloat = UIScreen.main.bounds.height) -> CGFloat {
        let refMin: CGFloat = 667
        let refMax: CGFloat = 956
        return Swift.min(1, Swift.max(0, (height - refMin) / (refMax - refMin)))
    }

    static func adaptiveValue(from start: CGFloat, to end: CGFloat, forHeight height: CGFloat = UIScreen.main.bounds.height) -> CGFloat {
        start + (end - start) * adaptiveHeightProgress(forHeight: height)
    }

    static func loadingLogoTopInset(forHeight height: CGFloat = UIScreen.main.bounds.height) -> CGFloat {
        adaptiveValue(from: 150, to: 227, forHeight: height)
    }

    static func panelHorizontalInset() -> CGFloat {
        adaptiveValue(from: 12, to: 16)
    }
}
