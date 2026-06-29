//
//  ServerHostCellView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

class ServerHostCellView: NSTableCellView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let tf = NSTextField()
        tf.isEditable = false
        tf.isBordered = false
        tf.backgroundColor = .clear
        tf.font = .systemFont(ofSize: 13)
        textField = tf
        addSubview(tf)
        tf.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-12)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
