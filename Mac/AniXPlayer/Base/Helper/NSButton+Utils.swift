//
//  NSButton+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa

extension NSButton {
    var isOn: Bool {
        get {
            return self.state == .on
        }
        
        set {
            self.state = newValue == true ? .on : .off
        }
    }
}
