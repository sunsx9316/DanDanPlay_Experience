//
//  ANXColor+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/6/29.
//

import Foundation

// MARK: - 品牌色 & 便捷 Init（internal，跨平台共用）

extension ANXColor {

    /// macOS 上 NSColor 已有 CGFloat 版本的同名 init，Int 版本会导致歧义
    convenience init(red: Int, green: Int, blue: Int, alpha: CGFloat = 1) {
        self.init(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
    }

    static var defaultMainColor: ANXColor {
        return ANXColor(anxRgb: 0x14B409)
    }

    static var mainColor: ANXColor {
        return Preferences.shared.mainColor
    }
}

// MARK: - RGB 互换（public）

public extension ANXColor {

    convenience init(anxRgb rgbValue: Int) {
        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                     green: CGFloat((rgbValue & 0xFF00) >> 8) / 255.0,
                     blue: CGFloat((rgbValue & 0xFF)) / 255.0,
                     alpha: 1)
    }

    var anxRgbValue: Int {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0

        #if os(macOS)
        r = self.redComponent
        g = self.greenComponent
        b = self.blueComponent
        #else
        self.getRed(&r, green: &g, blue: &b, alpha: nil)
        #endif

        r = r * 255 * 256 * 256
        g = g * 255 * 256
        b = b * 255

        return Int(r + g + b)
    }
}
