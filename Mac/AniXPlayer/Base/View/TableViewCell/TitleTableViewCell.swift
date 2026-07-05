//
//  TitleTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa
import SnapKit

class TitleTableViewCell: NSView {

    lazy var label = Label()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = nil
        label.toolTip = nil
    }
}
