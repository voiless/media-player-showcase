import UIKit

extension UILabel {

    func fitTextWithinBounds(multiline: Bool = true, preferredMaxLayoutWidth: CGFloat? = nil) {
        if multiline {
            numberOfLines = 0
            lineBreakMode = .byWordWrapping
            adjustsFontSizeToFitWidth = true
            minimumScaleFactor = 0.5
            if let w = preferredMaxLayoutWidth, w > 0 {
                self.preferredMaxLayoutWidth = w
            }
        } else {
            numberOfLines = 1
            lineBreakMode = .byTruncatingTail
            adjustsFontSizeToFitWidth = true
            minimumScaleFactor = 0.5
        }
    }
}

final class FittingLabel: UILabel {
    override func layoutSubviews() {
        super.layoutSubviews()
        if numberOfLines != 1, bounds.width > 0, preferredMaxLayoutWidth != bounds.width {
            preferredMaxLayoutWidth = bounds.width
            setNeedsUpdateConstraints()
        }
    }
}

extension UIButton {

    func fitTitleWithinBounds(maxLines: Int = 2) {
        titleLabel?.numberOfLines = maxLines
        titleLabel?.lineBreakMode = .byWordWrapping
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.5
    }
}

extension UITableViewCell {

    func fitTextLabelsWithinBounds() {
        textLabel?.fitTextWithinBounds(multiline: true)
        detailTextLabel?.fitTextWithinBounds(multiline: true)
    }
}
