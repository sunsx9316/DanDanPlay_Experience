//
//  ServerHostSectionCellView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

class ServerHostSectionCellView: NSTableCellView {

    private(set) lazy var refreshButton: NSButton = {
        let btn = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)!, target: nil, action: nil)
        btn.bezelStyle = .inline
        btn.isBordered = false
        return btn
    }()

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

        addSubview(refreshButton)
        refreshButton.snp.makeConstraints { make in
            make.leading.equalTo(tf.snp.trailing).offset(4)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
