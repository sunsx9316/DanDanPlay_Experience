//
//  TitleMoreTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/5.
//

import UIKit
import SnapKit

class TitleMoreTableViewCell: TableViewCell {

    lazy var label: Label = {
        let label = Label()
        label.numberOfLines = 0
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

        contentView.addSubview(label)
        contentView.addSubview(arrowImgView)

        label.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(15)
            make.bottom.equalToSuperview().offset(-10)
        }

        arrowImgView.snp.makeConstraints { make in
            make.centerY.equalTo(label)
            make.trailing.equalToSuperview().offset(-10)
            make.leading.greaterThanOrEqualTo(label.snp.trailing).offset(10)
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
