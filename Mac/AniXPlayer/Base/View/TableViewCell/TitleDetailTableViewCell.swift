//
//  TitleDetailTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa
import SnapKit

class TitleDetailTableViewCell: NSView {

    lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large
        return label
    }()

    lazy var subtitleLabel: Label = {
        let label = Label()
        label.font = .ddp_normal
        label.textColor = .subtitleTextColor
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(10)
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom).offset(10)
            make.bottom.equalToSuperview().offset(-10)
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
