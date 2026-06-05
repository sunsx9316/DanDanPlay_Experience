//
//  NSFont+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa

extension NSFont {

    static var ddp_small: NSFont { ddp_small() }

    static var ddp_normal: NSFont { ddp_normal() }

    static var ddp_large: NSFont { ddp_large() }

    static var ddp_huge: NSFont { ddp_huge() }

    static func ddp_small(weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.systemFont(ofSize: 13, weight: weight)
    }

    static func ddp_normal(weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.systemFont(ofSize: 15, weight: weight)
    }

    static func ddp_large(weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.systemFont(ofSize: 17, weight: weight)
    }

    static func ddp_huge(weight: NSFont.Weight = .regular) -> NSFont {
        return NSFont.systemFont(ofSize: 21, weight: weight)
    }
}
