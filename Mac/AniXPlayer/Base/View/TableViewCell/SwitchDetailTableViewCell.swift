//
//  SwitchDetailTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa
import SnapKit

class SwitchDetailTableViewCell: NSView {

    lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large
        return label
    }()

    lazy var subtitleLabel: Label = {
        let label = Label()
        label.textColor = .subtitleTextColor
        return label
    }()

    lazy var aSwitch = CheckBox()

    var onTouchSwitchCallBack: ((SwitchDetailTableViewCell) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleLabel)
        addSubview(aSwitch)
        addSubview(subtitleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(10)
        }
        aSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom).offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }
        aSwitch.addTarget(self, action: #selector(onTouchSwitch(_:)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc private func onTouchSwitch(_ sender: NSButton) {
        onTouchSwitchCallBack?(self)
    }
}
