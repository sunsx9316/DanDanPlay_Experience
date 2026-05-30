//
//  FilterDanmakuTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/3.
//

import UIKit

class FilterDanmakuTableViewCell: TableViewCell {

    lazy var titleLabel: Label = {
        let label = Label()
        label.numberOfLines = 0
        return label
    }()

    lazy var subtitleButton: Button = {
        let btn = Button()
        btn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        btn.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return btn
    }()

    lazy var aSwitch: UISwitch = {
        let s = UISwitch()
        return s
    }()

    var onTouchSwitchCallBack: ((FilterDanmakuTableViewCell) -> Void)?

    var onTouchSubtitleButtonCallBack: ((FilterDanmakuTableViewCell) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundView?.backgroundColor = .clear
        self.backgroundColor = .clear

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleButton)
        contentView.addSubview(aSwitch)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(15)
            make.bottom.equalToSuperview().offset(-10)
        }

        subtitleButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(10)
        }

        aSwitch.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-10)
            make.leading.equalTo(subtitleButton.snp.trailing).offset(10)
        }

        aSwitch.addTarget(self, action: #selector(onTouchSwitch(_:)), for: .valueChanged)
        subtitleButton.addTarget(self, action: #selector(onTouchSubtitleButton(_:)), for: .touchUpInside)

        self.titleLabel.font = .ddp_large
        self.subtitleButton.setTitleColor(.subtitleTextColor, for: .normal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onTouchSwitch(_ sender: UISwitch) {
        self.onTouchSwitchCallBack?(self)
    }

    @objc private func onTouchSubtitleButton(_ sender: UIButton) {
        self.onTouchSubtitleButtonCallBack?(self)
    }

}
