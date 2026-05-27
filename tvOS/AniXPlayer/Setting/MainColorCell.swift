//
//  MainColorCell.swift
//  AniXPlayer
//
//  tvOS 主题色选择 Cell
//

import UIKit
import SnapKit

class MainColorCell: CollectionViewCell {

    static let reuseIdentifier = "MainColorCell"

    private lazy var colorView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.clear.cgColor
        return view
    }()

    private lazy var checkmarkImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "checkmark"))
        iv.tintColor = .white
        iv.isHidden = true
        return iv
    }()

    private lazy var defaultLabel: Label = {
        let label = Label()
        label.text = NSLocalizedString("默认", comment: "")
        label.font = .ddp_small()
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.clipsToBounds = false
        contentView.addSubview(colorView)
        colorView.addSubview(checkmarkImageView)
        colorView.addSubview(defaultLabel)

        colorView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        checkmarkImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 30, height: 30))
        }

        defaultLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(4)
        }
    }

    func configure(with color: UIColor, isSelected: Bool, isDefault: Bool = false) {
        colorView.backgroundColor = isDefault ? .clear : color
        colorView.layer.borderWidth = isDefault && !isSelected ? 1 : 2
        colorView.layer.borderColor = {
            if isSelected { return UIColor.white.cgColor }
            if isDefault { return UIColor.secondaryLabel.cgColor }
            return UIColor.clear.cgColor
        }()
        defaultLabel.isHidden = !(isDefault && !isSelected)
        checkmarkImageView.isHidden = !isSelected
        if isDefault {
            checkmarkImageView.image = UIImage(systemName: "arrow.counterclockwise")
            checkmarkImageView.tintColor = isSelected ? .white : .secondaryLabel
        } else {
            checkmarkImageView.image = UIImage(systemName: "checkmark")
            checkmarkImageView.tintColor = .white
        }
    }

    // MARK: - Focus

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations({
            if self === context.nextFocusedView {
                self.colorView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            } else if self === context.previouslyFocusedView {
                self.colorView.transform = .identity
            }
        }, completion: nil)
    }
}
