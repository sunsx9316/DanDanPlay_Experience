//
//  NSControl+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/12.
//

import Cocoa

private var HandleCallBackKey = 0

typealias ANXHandleAction = (NSControl) -> Void

extension NSControl {
    
    private var handleCallBack: ANXHandleAction? {
        get {
            return objc_getAssociatedObject(self, &HandleCallBackKey) as? ANXHandleAction
        }
        
        set {
            objc_setAssociatedObject(self, &HandleCallBackKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func addTarget(_ target: AnyObject?, action: Selector?) {
        self.target = target
        self.action = action
    }
    
    func addAction(_ action: @escaping ANXHandleAction) {
        self.target = self
        self.action = #selector(handleAction(_:))
        self.handleCallBack = action
    }
    
    @objc private func handleAction(_ sender: NSControl) {
        self.handleCallBack?(sender)
    }
    
}
