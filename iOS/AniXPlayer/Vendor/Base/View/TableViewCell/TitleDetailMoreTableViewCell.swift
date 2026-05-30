//
//  TitleDetailMoreTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/14.
//

import UIKit
import SnapKit

class TitleDetailMoreTableViewCell: TableViewCell {

    lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large
        label.numberOfLines = 0
        return label
    }()

    lazy var subtitleLabel: Label = {
        let label = Label()
        label.textColor = .subtitleTextColor
        label.numberOfLines = 0
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return label
    }()

    lazy var arrowImgView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(arrowImgView)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(15)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-10)
        }

        arrowImgView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-10)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(10)
            make.leading.greaterThanOrEqualTo(subtitleLabel.snp.trailing).offset(10)
            make.width.height.equalTo(10)
        }

        self.setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.setupUI()
    }

    private func setupUI() {
        self.arrowImgView.image = UIImage(named: "Public/right_arrow")?.byTintColor(.indicatorColor)
    }
}
