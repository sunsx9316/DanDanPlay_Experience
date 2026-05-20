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

    private let colorView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.clear.cgColor
        return view
    }()

    private let checkmarkImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "checkmark"))
        iv.tintColor = .white
        iv.isHidden = true
        return iv
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
        contentView.addSubview(colorView)
        colorView.addSubview(checkmarkImageView)

        colorView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        checkmarkImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 30, height: 30))
        }
    }

    func configure(with color: UIColor, isSelected: Bool) {
        colorView.backgroundColor = color
        colorView.layer.borderColor = isSelected ? UIColor.white.cgColor : UIColor.clear.cgColor
        checkmarkImageView.isHidden = !isSelected
    }
}
