//
//  MediaLibraryItemCellView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/4.
//

import Cocoa
import SnapKit

class MediaLibraryItemCellView: NSTableCellView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.contentTintColor = NSColor.mainColor
        imageView = iv
        addSubview(iv)
        iv.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }

        let tf = NSTextField()
        tf.isEditable = false
        tf.isBordered = false
        tf.backgroundColor = .clear
        tf.font = .systemFont(ofSize: 14)
        textField = tf
        addSubview(tf)
        tf.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(58)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
