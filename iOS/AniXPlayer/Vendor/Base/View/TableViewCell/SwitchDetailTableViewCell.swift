//
//  SwitchDetailTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/3.
//

import UIKit
import SnapKit

class SwitchDetailTableViewCell: TableViewCell {

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
        return label
    }()

    lazy var aSwitch: UISwitch = {
        let s = UISwitch()
        return s
    }()

    var onTouchSliderCallBack: ((SwitchDetailTableViewCell) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(aSwitch)

        aSwitch.addTarget(self, action: #selector(onTouchSwitch(_:)), for: .valueChanged)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(15)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.equalTo(titleLabel)
            make.bottom.greaterThanOrEqualToSuperview().offset(-10)
        }

        aSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(10)
            make.leading.equalTo(subtitleLabel.snp.trailing).offset(10)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onTouchSwitch(_ sender: UISwitch) {
        self.onTouchSliderCallBack?(self)
    }
}
