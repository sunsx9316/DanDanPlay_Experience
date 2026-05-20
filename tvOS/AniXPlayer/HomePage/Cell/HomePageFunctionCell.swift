//
//  HomePageFunctionCell.swift
//  AniXPlayer
//
//  tvOS 首页"功能入口"Cell
//

import UIKit
import SnapKit

class HomePageFunctionCell: CollectionViewCell {

    static let reuseIdentifier = "HomePageFunctionCell"

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        return iv
    }()

    private let nameLabel: Label = {
        let label = Label()
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .lightGray
        label.textAlignment = .center
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
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        contentView.layer.cornerRadius = 12

        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)

        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20)
            make.size.equalTo(CGSize(width: 48, height: 48))
        }

        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
        }
    }

    func configure(title: String, iconName: String) {
        nameLabel.text = title
        iconImageView.image = UIImage(systemName: iconName)
    }
}
