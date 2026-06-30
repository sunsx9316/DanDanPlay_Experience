//
//  NeighborServiceCellView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/30.
//

import Cocoa
import SnapKit

class NeighborServiceCellView: NSTableCellView {

    let titleLabel: Label = {
        let tf = Label()
        tf.font = .ddp_small()
        return tf
    }()

    let detailLabel: Label = {
        let tf = Label()
        tf.font = .ddp_small()
        tf.textColor = .secondaryLabelColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 1
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
