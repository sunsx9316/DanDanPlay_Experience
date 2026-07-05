//
//  SwitchTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa
import SnapKit

class SwitchTableViewCell: NSView {

    lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_normal
        return label
    }()

    lazy var aSwitch = CheckBox()

    var onTouchSliderCallBack: ((SwitchTableViewCell) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleLabel)
        addSubview(aSwitch)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }
        aSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(10)
        }
        aSwitch.addTarget(self, action: #selector(onTouchSwitch(_:)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc private func onTouchSwitch(_ sender: NSButton) {
        onTouchSliderCallBack?(self)
    }
}
