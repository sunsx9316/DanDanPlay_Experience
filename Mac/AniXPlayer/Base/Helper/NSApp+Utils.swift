//
//  NSApp+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/17.
//

import Cocoa

extension NSApplication {
    var appDelegate: AppDelegate? {
        return self.delegate as? AppDelegate
    }
}
