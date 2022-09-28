//
//  NSGestureRecognizer+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/28.
//

import Foundation
import AppKit

typealias ANXGestureRecognizerAction = (NSGestureRecognizer) -> Void

private var NSGestureRecognizerActionKey = 0

extension NSGestureRecognizer {
    
    private var actionBlock: ANXGestureRecognizerAction? {
        set {
            objc_setAssociatedObject(self, &NSGestureRecognizerActionKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
        
        get {
            if let action = objc_getAssociatedObject(self, &NSGestureRecognizerActionKey) as? ANXGestureRecognizerAction {
                return action
            }
            return nil
        }
    }
    
    func add(_ action: @escaping(ANXGestureRecognizerAction)) {
        self.actionBlock = action
        self.target = self
        self.action = #selector(onGestureResponse(_:))
    }
    
    @objc private func onGestureResponse(_ ges: NSGestureRecognizer) {
        self.actionBlock?(ges)
    }
}
