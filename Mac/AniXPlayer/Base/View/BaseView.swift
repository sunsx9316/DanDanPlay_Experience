//
//  BaseView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa

class BaseView: NSView {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInit()
    }
    
    private func setupInit() {
        self.wantsLayer = true
    }
    
    
    
}
