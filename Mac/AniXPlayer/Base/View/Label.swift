//
//  Label.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa

class Label: NSTextField {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }

    // MARK: - Private

    private func setupInit() {
        self.isEditable = false
        self.isBordered = false
        self.drawsBackground = false
        self.font = .ddp_normal
        self.textColor = .textColor
    }
}
