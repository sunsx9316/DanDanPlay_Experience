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
}

#endif
