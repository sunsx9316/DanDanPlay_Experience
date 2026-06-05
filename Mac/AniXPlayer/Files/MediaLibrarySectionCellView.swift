//
//  MediaLibrarySectionCellView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/4.
//

import Cocoa
import SnapKit

class MediaLibrarySectionCellView: NSTableCellView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let tf = NSTextField()
        tf.isEditable = false
        tf.isBordered = false
        tf.backgroundColor = .clear
        tf.font = .systemFont(ofSize: 11, weight: .semibold)
        tf.textColor = .secondaryLabelColor
        textField = tf
        addSubview(tf)
        tf.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
