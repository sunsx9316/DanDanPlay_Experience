//
//  NSColor+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Foundation
import DDPCategory

extension NSColor {
    
    convenience init(red: Int, green: Int, blue: Int, alpha: CGFloat = 1) {
        let normalizedRed = CGFloat(red) / 255
        let normalizedGreen = CGFloat(green) / 255
        let normalizedBlue = CGFloat(blue) / 255

        self.init(red: normalizedRed, green: normalizedGreen, blue: normalizedBlue, alpha: alpha)
    }
    
    private static func byName(_ name: String) -> NSColor {
        if let color = NSColor(named: name) {
            return color
        }
        assert(false, "未找到颜色 \(name)")
        return .white
    }
    
    static var mainColor: NSColor {
        return NSColor(red: 20, green: 180, blue: 9)
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
