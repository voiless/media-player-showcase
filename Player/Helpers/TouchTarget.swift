import UIKit

// MARK: - DEV-0002 — единая математика области нажатия
//
// По каждой оси цель: max(2×текущий размер, 44pt), пока ось «мала».
// Если обе оси уже ≥ 44pt (например центральная кнопка таб-бара 60×60), расширение не добавляем —
// иначе пересечения с соседними зонами дают ложные нажатия.

enum TouchTarget {
    static let minimumSide: CGFloat = 44

    /// Положительные полуотступы: на сколько расширить hit с каждой стороны.
    static func expansionHalfDeltas(forBounds bounds: CGRect) -> (dx: CGFloat, dy: CGFloat) {
        let w = bounds.width
        let h = bounds.height
        let wideOk = w >= minimumSide
        let tallOk = h >= minimumSide
        if wideOk && tallOk { return (0, 0) }

        let tw = wideOk ? w : max(w * 2, minimumSide)
        let th = tallOk ? h : max(h * 2, minimumSide)
        let dx = (tw - w) / 2
        let dy = (th - h) / 2
        return (dx, dy)
    }

    /// Отрицательные inset для `bounds.inset(by:)` — расширение наружу.
    static func hitInsets(forBounds bounds: CGRect) -> UIEdgeInsets {
        let (dx, dy) = expansionHalfDeltas(forBounds: bounds)
        guard dx > 0 || dy > 0 else { return .zero }
        return UIEdgeInsets(top: -dy, left: -dx, bottom: -dy, right: -dx)
    }
}

/// Кнопка с расширенным hit-test по правилам `TouchTarget` (без изменения layout).
class TouchTargetButton: UIButton {

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let insets = TouchTarget.hitInsets(forBounds: bounds)
        if insets == .zero {
            return super.point(inside: point, with: event)
        }
        let expanded = bounds.inset(by: insets)
        return expanded.contains(point)
    }
}

// MARK: - UIBarButtonItem — иконки в зоне ≥ 44×44

extension UIBarButtonItem {

    /// Стандартный «назад» с chevron в достаточной области нажатия.
    static func touchTargetBackChevron(target: Any?, action: Selector?) -> UIBarButtonItem {
        touchTargetIcon(image: UIImage(systemName: "chevron.left"), target: target, action: action)
    }

    /// Кнопка «+» как у system `.add`, в квадрате minimumSide.
    static func touchTargetAdd(target: Any?, action: Selector?) -> UIBarButtonItem {
        let btn = TouchTargetButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        btn.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        btn.frame = CGRect(x: 0, y: 0, width: TouchTarget.minimumSide, height: TouchTarget.minimumSide)
        btn.contentHorizontalAlignment = .fill
        btn.contentVerticalAlignment = .fill
        if let t = target, let a = action {
            btn.addTarget(t, action: a, for: .touchUpInside)
        }
        return UIBarButtonItem(customView: btn)
    }

    static func touchTargetEllipsis(target: Any?, action: Selector?) -> UIBarButtonItem {
        touchTargetIcon(image: UIImage(systemName: "ellipsis"), target: target, action: action)
    }

    static func touchTargetIcon(image: UIImage?, target: Any?, action: Selector?) -> UIBarButtonItem {
        let btn = TouchTargetButton(type: .system)
        btn.setImage(image, for: .normal)
        btn.frame = CGRect(x: 0, y: 0, width: TouchTarget.minimumSide, height: TouchTarget.minimumSide)
        btn.contentHorizontalAlignment = .center
        btn.contentVerticalAlignment = .center
        if let t = target, let a = action {
            btn.addTarget(t, action: a, for: .touchUpInside)
        }
        return UIBarButtonItem(customView: btn)
    }
}
