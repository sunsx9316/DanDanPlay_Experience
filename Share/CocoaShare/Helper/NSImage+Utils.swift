//
//  NSImage+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Foundation

#if os(macOS)

extension NSImage {
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }
}

#endif
