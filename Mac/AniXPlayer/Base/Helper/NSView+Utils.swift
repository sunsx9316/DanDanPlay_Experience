//
//  NSView+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa
import QuartzCore

extension NSView {
    
    var bgColor: NSColor? {
        set {
            if self.wantsLayer == false {
                self.wantsLayer = true
            }
            self.layer?.backgroundColor = newValue?.cgColor
        }
        
        get {
            if let color = self.layer?.backgroundColor {
                return NSColor(cgColor: color)
            }
            return nil
        }
    }
    
    var transform: CGAffineTransform {
        set {
            self.layer?.transform = CATransform3DMakeAffineTransform(newValue)
        }
        
        get {
            if let layer = self.layer {
                return CATransform3DGetAffineTransform(layer.transform)
            }
            return .identity
        }
    }
    
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
