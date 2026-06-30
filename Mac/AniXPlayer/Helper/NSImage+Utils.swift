//
//  NSImage+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

#if os(macOS)

import Cocoa

extension NSImage {
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }

    /// 安全创建 SF Symbol 图像，避免强制解包
    static func safeSystemSymbol(_ name: String) -> NSImage {
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }
}

#endif
