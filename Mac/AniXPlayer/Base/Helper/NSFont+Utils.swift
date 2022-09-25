//
//  NSFont+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa

extension NSFont {
    
    static var ddp_small: NSFont {
        return NSFont.systemFont(ofSize: 13)
    }
    
    static var ddp_normal: NSFont {
        return NSFont.systemFont(ofSize: 15)
    }
    
    static var ddp_large: NSFont {
        return NSFont.systemFont(ofSize: 17)
    }
    
    static var ddp_huge: NSFont {
        return NSFont.systemFont(ofSize: 21)
    }
}
