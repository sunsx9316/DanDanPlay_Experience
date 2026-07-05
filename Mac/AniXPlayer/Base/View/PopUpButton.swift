//
//  PopUpButton.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/5.
//

import Cocoa

class PopUpButton: NSPopUpButton {

    override init(frame frameRect: NSRect, pullsDown flag: Bool) {
        super.init(frame: frameRect, pullsDown: flag)
        setupInit()
    }

    convenience init() {
        self.init(frame: .zero, pullsDown: false)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInit()
    }

    private func setupInit() {
        contentTintColor = .mainColor
    }
}
