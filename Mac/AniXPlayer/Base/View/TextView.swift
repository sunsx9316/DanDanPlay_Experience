//
//  TextView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/5.
//

import Cocoa

class TextView: NSTextView {

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        self.setupInit()
    }

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
        self.isSelectable = true
        self.drawsBackground = false
        self.backgroundColor = .clear
        self.font = .ddp_normal
        self.textColor = .textColor
        self.textContainerInset = .zero
        self.textContainer?.lineFragmentPadding = 0
        self.isHorizontallyResizable = false
        self.isVerticallyResizable = true
    }
}
