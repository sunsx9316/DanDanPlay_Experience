//
//  OutlineView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa

class OutlineView: NSOutlineView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInit()
    }

    // MARK: Private

    private func setupInit() {
        headerView = nil
        style = .sourceList
    }
}
