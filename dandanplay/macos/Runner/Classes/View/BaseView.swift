//
//  BaseView.swift
//  Runner
//
//  Created by jimhuang on 2021/2/17.
//  Copyright © 2021 The Flutter Authors. All rights reserved.
//

import Cocoa

class BaseView: NSView {
    
    var isShouldFlipped = true
    
    override var isFlipped: Bool {
        return self.isShouldFlipped
    }
}
