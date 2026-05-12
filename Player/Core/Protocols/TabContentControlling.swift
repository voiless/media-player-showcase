import UIKit

protocol TabContentControlling: AnyObject {
    var onPlusTapped: (() -> Void)? { get set }
}
