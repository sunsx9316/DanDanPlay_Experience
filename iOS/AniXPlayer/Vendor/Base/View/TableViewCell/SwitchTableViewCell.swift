//
//  SwitchTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/22.
//

import UIKit
import SnapKit

class SwitchTableViewCell: TableViewCell {

    lazy var titleLabel: Label = {
        let label = Label()
        return label
    }()

    lazy var aSwitch: UISwitch = {
        let s = UISwitch()
        return s
    }()

    var onTouchSliderCallBack: ((SwitchTableViewCell) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(aSwitch)

        aSwitch.addTarget(self, action: #selector(onTouchSwitch(_:)), for: .valueChanged)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(15)
            make.centerY.equalToSuperview()
        }

        aSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(titleLabel)
            make.top.equalToSuperview().offset(6)
            make.bottom.equalToSuperview().offset(-6)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onTouchSwitch(_ sender: UISwitch) {
        self.onTouchSliderCallBack?(self)
    }
}
