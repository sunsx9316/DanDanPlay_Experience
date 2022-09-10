//
//  NSView+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Foundation

extension NSView {
    static func loadFromNib() -> Self? {
        
        let bundle = Bundle(for: self)
        let nibName = "\(self.self)"
        
        var arr: NSArray? = nil
        
        if bundle.loadNibNamed(nibName, owner: nil, topLevelObjects: &arr) {
            if let arr = arr {
                for aView in arr {
                    if let aView = aView as? Self {
                        return aView
                    }
                }
            }
        }
        
        return nil
    }
}
