import UIKit

enum AppFonts {
    private static func font(name: String, size: CGFloat) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }

    static func black(_ size: CGFloat) -> UIFont {
        font(name: "SFProDisplay-Black", size: size)
    }

    static func bold(_ size: CGFloat) -> UIFont {
        font(name: "SFProDisplay-Bold", size: size)
    }

    static func light(_ size: CGFloat) -> UIFont {
        font(name: "SFProDisplay-Light", size: size)
    }

    static func medium(_ size: CGFloat) -> UIFont {
        font(name: "SFProDisplay-Medium", size: size)
    }

    static func regular(_ size: CGFloat) -> UIFont {
        font(name: "SFProDisplay-Regular", size: size)
    }

    static func semibold(_ size: CGFloat) -> UIFont {
        font(name: "SFProDisplay-Semibold", size: size)
    }

    static func monospaced(size: CGFloat) -> UIFont {
        font(name: "SFProDisplay-Regular", size: size)
    }
}
