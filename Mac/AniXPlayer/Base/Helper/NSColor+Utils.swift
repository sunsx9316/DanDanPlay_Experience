//
//  NSColor+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Foundation
import YYCategories

extension NSColor {
    
    private static func byName(_ name: String) -> NSColor {
        if let color = NSColor(named: name) {
            return color
        }
        assert(false, "未找到颜色 \(name)")
        return .white
    }
    
    static var backgroundColor: NSColor {
        return .byName("Color/backgroundColor")
    }
    
    static var navItemColor: NSColor {
        return .byName("Color/navItemColor")
    }
    
    static var headViewBackgroundColor: NSColor {
        return .byName("Color/headViewBackgroundColor")
    }
    
    static var separatorColor: NSColor {
        return .byName("Color/separatorColor")
    }
    
    static var textColor: NSColor {
        return .byName("Color/textColor")
    }
    
    static var subtitleTextColor: NSColor {
        return .lightGray
    }
    
    static var navigationTitleColor: NSColor {
        return .byName("Color/navItemColor")
    }
    
    static var placeholderColor: NSColor {
        return .init(red: 240, green: 240, blue: 240)
    }
    
    static var cellHighlightColor: NSColor {
        return .byName("Color/cellHighlightColor")
    }
}
