//
//  ANXColor+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/6/29.
//

import Foundation

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
