//
//  NSMenuItem+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/16.
//

import Cocoa

typealias NSMenuItemAction = (NSMenuItem) -> Void

private var NSMenuItemActionKey = 0

extension NSMenuItem {
    
    private var actionBlock: NSMenuItemAction? {
        set {
            objc_setAssociatedObject(self, &NSMenuItemActionKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
        
        get {
            if let action = objc_getAssociatedObject(self, &NSMenuItemActionKey) as? NSMenuItemAction {
                return action
            }
            return nil
        }
    }
    
    convenience init(title: String, keyEquivalent: String = "", action: @escaping(NSMenuItemAction)) {
        self.init(title: title, action: #selector(onClickItem(_:)), keyEquivalent: keyEquivalent)
        self.actionBlock = action
        self.target = self
    }
    
    @objc private func onClickItem(_ item: NSMenuItem) {
        self.actionBlock?(item)
    }
}
