//
//  TextField.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa

class TextField: NSTextField {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    //MARK: Private
    private func setupInit() {
        self.font = .ddp_normal
        self.textColor = .textColor
    }
    
}
