import Foundation

enum PlaybackSpeed: Float, CaseIterable {
    case half = 0.5
    case normal = 1.0
    case oneQuarter = 1.25
    case oneHalf = 1.5
    case double = 2.0

    var displayName: String {
        return "\(rawValue)×"
    }
}
