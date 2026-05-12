import AVKit
import UIKit

final class TransmittingDeviceViewController: UIViewController {

    private static let modalBackgroundColor = UIColor(red: 0x22/255, green: 0x1C/255, blue: 0x2E/255, alpha: 1)
    private static let buttonBackgroundColor = UIColor(red: 0x3A/255, green: 0x2B/255, blue: 0x44/255, alpha: 1)
    private static let cornerRadius: CGFloat = 18
    private static let buttonInsetPhone: CGFloat = 10
    private static let buttonInsetPad: CGFloat = 93

    private let dimmingView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = TransmittingDeviceViewController.modalBackgroundColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = AppStrings.selectingTransmittingDevice
        l.font = AppFonts.semibold(17)
        l.textColor = .white
        l.textAlignment = .center
        l.fitTextWithinBounds(multiline: true)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let airPlayContainer: UIView = {
        let v = UIView()
        v.backgroundColor = TransmittingDeviceViewController.buttonBackgroundColor
        v.layer.cornerRadius = AppColors.cardCornerRadius
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let airPlayLabel: UILabel = {
        let l = UILabel()
        l.text = AppStrings.airPlayOrBluetooth
        l.font = AppFonts.regular(17)
        l.textColor = .white
        l.fitTextWithinBounds(multiline: false)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var airPlayRoutePickerView: AVRoutePickerView = {
        let v = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        v.activeTintColor = .white
        v.tintColor = .white
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let transmittingButton: UIButton = {
        let b = TouchTargetButton(type: .system)
        b.setTitle(AppStrings.transmittingDevices, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = AppFonts.regular(17)
        b.fitTitleWithinBounds(maxLines: 2)
        b.backgroundColor = TransmittingDeviceViewController.buttonBackgroundColor
        b.layer.cornerRadius = AppColors.cardCornerRadius
        b.contentHorizontalAlignment = .left
        b.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let img = UIImage(systemName: "antenna.radiowaves.left.and.right", withConfiguration: config)
        b.setImage(img, for: .normal)
        b.tintColor = .white
        b.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: -12)
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(dimmingView)
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(airPlayContainer)
        airPlayContainer.addSubview(airPlayLabel)
        airPlayContainer.addSubview(airPlayRoutePickerView)
        containerView.addSubview(transmittingButton)
        containerView.layer.cornerRadius = Self.cornerRadius
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds = true
        let buttonInset: CGFloat = traitCollection.userInterfaceIdiom == .pad ? Self.buttonInsetPad : Self.buttonInsetPhone
        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            titleLabel.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            airPlayContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            airPlayContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: buttonInset),
            airPlayContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -buttonInset),
            airPlayContainer.heightAnchor.constraint(equalToConstant: 52),
            airPlayLabel.leadingAnchor.constraint(equalTo: airPlayContainer.leadingAnchor, constant: 16),
            airPlayLabel.centerYAnchor.constraint(equalTo: airPlayContainer.centerYAnchor),
            airPlayLabel.trailingAnchor.constraint(lessThanOrEqualTo: airPlayRoutePickerView.leadingAnchor, constant: -8),
            airPlayRoutePickerView.trailingAnchor.constraint(equalTo: airPlayContainer.trailingAnchor, constant: -12),
            airPlayRoutePickerView.centerYAnchor.constraint(equalTo: airPlayContainer.centerYAnchor),
            airPlayRoutePickerView.widthAnchor.constraint(equalToConstant: 44),
            airPlayRoutePickerView.heightAnchor.constraint(equalToConstant: 44),
            transmittingButton.topAnchor.constraint(equalTo: airPlayContainer.bottomAnchor, constant: 12),
            transmittingButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: buttonInset),
            transmittingButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -buttonInset),
            transmittingButton.heightAnchor.constraint(equalToConstant: 52),
            transmittingButton.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
        let tapDimming = UITapGestureRecognizer(target: self, action: #selector(dimmingTapped))
        dimmingView.addGestureRecognizer(tapDimming)
        transmittingButton.addTarget(self, action: #selector(transmittingTapped), for: .touchUpInside)
    }

    @objc private func dimmingTapped() {
        dismiss(animated: true)
    }

    @objc private func transmittingTapped() {
        dismiss(animated: true)
    }
}
