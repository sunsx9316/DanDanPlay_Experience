//
//  CheckBox.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/5.
//

import Cocoa

class CheckBox: NSButton {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInit()
    }

    private func setupInit() {
        setButtonType(.switch)
        title = ""
        contentTintColor = .mainColor
    }
}
