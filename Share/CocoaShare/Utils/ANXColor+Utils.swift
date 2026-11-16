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
        // NSColor 可能是 catalog/dynamic/pattern color，直接读 redComponent 在部分 macOS
        // 版本会抛 color-space 异常。先转换到 sRGB，再读取分量；转换失败返回黑色。
        guard let rgb = self.usingColorSpace(.sRGB) ?? self.usingColorSpace(.deviceRGB) else {
            return 0
        }
        r = rgb.redComponent
        g = rgb.greenComponent
        b = rgb.blueComponent
        #else
        self.getRed(&r, green: &g, blue: &b, alpha: nil)
        #endif

        r = r * 255 * 256 * 256
        g = g * 255 * 256
        b = b * 255

        return Int(r + g + b)
    }
}
