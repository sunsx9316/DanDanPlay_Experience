//
//  NSTextField+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa

extension NSTextField {
    var text: String? {
        set {
            self.stringValue = newValue ?? ""
        }
        
        get {
            return self.stringValue
        }
    }
    
}

extension NSSearchField {

    /// 搜索框只在按下 Return 或点击「搜索」按钮时提交；
    /// 输入、删除、粘贴文字时不自动发送 action。
    func configureSearchOnReturn() {
        sendsWholeSearchString = true
        sendsSearchStringImmediately = false
    }
}
