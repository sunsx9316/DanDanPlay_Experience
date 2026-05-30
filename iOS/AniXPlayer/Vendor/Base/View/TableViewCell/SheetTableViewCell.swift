//
//  SheetTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/23.
//

import UIKit
import SnapKit

class SheetTableViewCell: TableViewCell {

    lazy var titleLabel: Label = {
        let label = Label()
        return label
    }()

    lazy var arrowImgView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: "Public/right_arrow")?.byTintColor(.indicatorColor)
        return iv
    }()

    lazy var valueLabel: Label = {
        let label = Label()
        label.textAlignment = .right
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(arrowImgView)
        contentView.addSubview(valueLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
        }

        arrowImgView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(titleLabel)
            make.width.height.equalTo(10)
        }

        valueLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(10)
            make.centerY.equalTo(titleLabel)
            make.trailing.equalTo(arrowImgView.snp.leading).offset(-10)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
