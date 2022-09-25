//
//  NSControl+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/12.
//

import Cocoa

extension NSControl {
    func addTarget(_ target: AnyObject?, action: Selector?) {
        self.target = target
        self.action = action
    }
    
}
