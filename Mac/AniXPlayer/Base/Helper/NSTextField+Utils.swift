//
//  NSTextField+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa

extension NSTextField {
    var text: String? {
        set {
            self.stringValue = newValue ?? ""
        }
        
        get {
            return self.stringValue
        }
    }
    
}
