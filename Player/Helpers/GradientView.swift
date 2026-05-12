import UIKit

final class GradientView: UIView {

    var gradientColors: [UIColor] = [] {
        didSet { gradientLayer.colors = gradientColors.map(\.cgColor) }
    }

    var startPoint: CGPoint = CGPoint(x: 0, y: 0) {
        didSet { gradientLayer.startPoint = startPoint }
    }

    var endPoint: CGPoint = CGPoint(x: 1, y: 1) {
        didSet { gradientLayer.endPoint = endPoint }
    }

    private let gradientLayer: CAGradientLayer = {
        let l = CAGradientLayer()
        l.startPoint = CGPoint(x: 0, y: 0)
        l.endPoint = CGPoint(x: 1, y: 1)
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

final class SegmentGradientTextView: UIView {
    private static let start = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1)
    private static let end = UIColor(red: 0xA2/255, green: 0x84/255, blue: 0xF6/255, alpha: 1)

    private var title: String = ""
    private var font: UIFont = .systemFont(ofSize: 14)

    private let gradientLayer: CAGradientLayer = {
        let l = CAGradientLayer()
        l.colors = [SegmentGradientTextView.start.cgColor, SegmentGradientTextView.end.cgColor]
        l.startPoint = CGPoint(x: 0, y: 0)
        l.endPoint = CGPoint(x: 1, y: 0.13)
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) { nil }

    func setTitle(_ title: String, font: UIFont) {
        self.title = title
        self.font = font
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        guard !title.isEmpty else { return .zero }
        let size = (title as NSString).size(withAttributes: [.font: font])
        return size
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        var drawFont = font
        var textSize = (title as NSString).size(withAttributes: [.font: drawFont])
        if bounds.width > 0 && textSize.width > bounds.width {
            let scale = bounds.width / textSize.width
            let newPointSize = max(9, font.pointSize * scale)
            drawFont = font.withSize(newPointSize)
            textSize = (title as NSString).size(withAttributes: [.font: drawFont])
        }
        let textLayer = CATextLayer()
        textLayer.string = title
        textLayer.font = drawFont
        textLayer.fontSize = drawFont.pointSize
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .center
        let scale = UIScreen.main.scale
        textLayer.contentsScale = scale
        gradientLayer.contentsScale = scale
        let x = (bounds.width - textSize.width) / 2
        let y = (bounds.height - textSize.height) / 2
        textLayer.frame = CGRect(
            x: round(x * scale) / scale,
            y: round(y * scale) / scale,
            width: min(round(textSize.width * scale) / scale, bounds.width),
            height: round(textSize.height * scale) / scale
        )
        gradientLayer.mask = textLayer
    }
}

final class GradientLineView: UIView {
    private let gradientLayer: CAGradientLayer = {
        let l = CAGradientLayer()
        l.colors = [AppColors.gradientStart.cgColor, AppColors.gradientEnd.cgColor]
        l.startPoint = CGPoint(x: 0, y: 0.5)
        l.endPoint = CGPoint(x: 1, y: 0.5)
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

final class BestOfferBadgeView: UIView {
    private static let start = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1)
    private static let end = UIColor(red: 0xA2/255, green: 0x84/255, blue: 0xF6/255, alpha: 1)
    private static let size = CGSize(width: 111, height: 22)
    private static let cornerRadius: CGFloat = 10
    private static let borderWidth: CGFloat = 1

    private let outerGradient = CAGradientLayer()
    private let innerView = GradientView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        outerGradient.colors = [Self.start.cgColor, Self.end.cgColor]
        outerGradient.startPoint = CGPoint(x: 0, y: 0)
        outerGradient.endPoint = CGPoint(x: 1, y: 0.13)
        layer.addSublayer(outerGradient)
        innerView.gradientColors = [Self.start, Self.end]
        innerView.startPoint = CGPoint(x: 0, y: 0)
        innerView.endPoint = CGPoint(x: 1, y: 0.13)
        innerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(innerView)
        label.text = AppStrings.theBestOffer
        label.font = AppFonts.regular(12)
        label.textColor = .white
        label.fitTextWithinBounds(multiline: false)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        let labelPadding: CGFloat = 8
        NSLayoutConstraint.activate([
            innerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.borderWidth),
            innerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.borderWidth),
            innerView.topAnchor.constraint(equalTo: topAnchor, constant: Self.borderWidth),
            innerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.borderWidth),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: labelPadding),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -labelPadding),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = Self.cornerRadius
        innerView.layer.cornerRadius = Self.cornerRadius - Self.borderWidth
        innerView.clipsToBounds = true
        outerGradient.frame = bounds
        outerGradient.cornerRadius = Self.cornerRadius
    }

    static var intrinsicSize: CGSize { size }
}
