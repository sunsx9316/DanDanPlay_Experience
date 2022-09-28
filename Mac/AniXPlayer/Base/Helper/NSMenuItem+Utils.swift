//
//  NSMenuItem+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/16.
//

import Cocoa

typealias ANXMenuItemAction = (NSMenuItem) -> Void

private var NSMenuItemActionKey = 0

extension NSMenuItem {
    
    private var actionBlock: ANXMenuItemAction? {
        set {
            objc_setAssociatedObject(self, &NSMenuItemActionKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
        
        get {
            if let action = objc_getAssociatedObject(self, &NSMenuItemActionKey) as? ANXMenuItemAction {
                return action
            }
            return nil
        }
    }
    
    convenience init(title: String, keyEquivalent: String = "", action: @escaping(ANXMenuItemAction)) {
        self.init(title: title, action: nil, keyEquivalent: keyEquivalent)
        self.add(action)
    }
    
    func add(_ action: @escaping(ANXMenuItemAction)) {
        self.actionBlock = action
        self.target = self
        self.action = #selector(onClickItem(_:))
    }
    
    @objc private func onClickItem(_ item: NSMenuItem) {
        self.actionBlock?(item)
    }
}
