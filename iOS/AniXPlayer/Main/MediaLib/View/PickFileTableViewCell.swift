//
//  PickFileTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/1.
//

import UIKit

class PickFileTableViewCell: TableViewCell {

    lazy var iconImgView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    lazy var titleLabel: Label = {
        let label = Label()
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

        contentView.addSubview(iconImgView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(arrowImgView)

        iconImgView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImgView.snp.trailing).offset(10)
            make.centerY.equalTo(iconImgView)
        }

        arrowImgView.snp.makeConstraints { make in
            make.centerY.equalTo(iconImgView)
            make.trailing.equalToSuperview().offset(-15)
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

    //MARK: Private
    private func setupUI() {
        self.arrowImgView.image = UIImage(named: "Public/right_arrow")?.byTintColor(.navItemColor)
    }
}
