//
//  Button.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/12.
//

import Cocoa

class Button: NSButton {
    
    static func custom() -> Button {
        let button = Button()
        button.bezelStyle = .texturedSquare
        button.isBordered = false
        return button
    }
    
}
