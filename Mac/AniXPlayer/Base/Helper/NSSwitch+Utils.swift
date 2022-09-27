//
//  NSSwitch+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/27.
//

import Cocoa

extension NSSwitch {
    var isOn: Bool {
        get {
            return self.state == .on
        }
        
        set {
            self.state = newValue == true ? .on : .off
        }
    }
}
