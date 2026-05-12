import UIKit

final class PaywallOptionCard: UIControl {
    private static let radioSize: CGFloat = 16
    private static let radioInnerSize: CGFloat = 8
    private static let purpleColor = UIColor(red: 0x88/255, green: 0x6A/255, blue: 0xE2/255, alpha: 1)

    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let radioView = UIView()
    private let radioInnerView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.15, alpha: 1)
        layer.cornerRadius = 15
        clipsToBounds = true

        titleLabel.font = AppFonts.regular(17)
        titleLabel.textColor = .white
        titleLabel.fitTextWithinBounds(multiline: false)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.font = AppFonts.regular(17)
        priceLabel.textColor = .white
        priceLabel.fitTextWithinBounds(multiline: false)
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        radioView.layer.cornerRadius = Self.radioSize / 2
        radioView.layer.borderWidth = 1
        radioView.layer.borderColor = UIColor.white.cgColor
        radioView.translatesAutoresizingMaskIntoConstraints = false
        radioInnerView.layer.cornerRadius = Self.radioInnerSize / 2
        radioInnerView.backgroundColor = Self.purpleColor
        radioInnerView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(priceLabel)
        addSubview(radioView)
        radioView.addSubview(radioInnerView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: priceLabel.leadingAnchor, constant: -8),
            priceLabel.trailingAnchor.constraint(equalTo: radioView.leadingAnchor, constant: -12),
            priceLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            radioView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            radioView.centerYAnchor.constraint(equalTo: centerYAnchor),
            radioView.widthAnchor.constraint(equalToConstant: Self.radioSize),
            radioView.heightAnchor.constraint(equalToConstant: Self.radioSize),
            radioInnerView.centerXAnchor.constraint(equalTo: radioView.centerXAnchor),
            radioInnerView.centerYAnchor.constraint(equalTo: radioView.centerYAnchor),
            radioInnerView.widthAnchor.constraint(equalToConstant: Self.radioInnerSize),
            radioInnerView.heightAnchor.constraint(equalToConstant: Self.radioInnerSize)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(title: String, price: String, badge: String?, selected: Bool) {
        titleLabel.text = title
        priceLabel.text = price
        setSelected(selected)
    }

    func setSelected(_ selected: Bool) {
        if selected {
            radioView.backgroundColor = .white
            radioView.layer.borderColor = UIColor.white.cgColor
            radioInnerView.isHidden = false
        } else {
            radioView.backgroundColor = .clear
            radioView.layer.borderColor = UIColor.white.cgColor
            radioInnerView.isHidden = true
        }
    }
}
