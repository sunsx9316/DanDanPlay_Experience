//
//  SectionHeaderCellView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/30.
//

import Cocoa
import SnapKit

class SectionHeaderCellView: NSTableCellView {

    private let label: Label = {
        let tf = Label()
        tf.font = .ddp_small(weight: .semibold)
        tf.textColor = .secondaryLabelColor
        return tf
    }()

    var title: String = "" {
        didSet {
            label.stringValue = title
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-12)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
