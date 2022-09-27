//
//  NSTableView+Tools.swift
//  Runner
//
//  Created by JimHuang on 2020/3/8.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa

private var RegisterClassKey = 0

extension NSTableView {
    
    //[NSUserInterfaceItemIdentifier: AnyClass]
    private var registerClassDic: NSMutableDictionary {
        get {
            if let dic = objc_getAssociatedObject(self, &RegisterClassKey) as? NSMutableDictionary {
                return dic
            }
            
            let dic = NSMutableDictionary()
            self.registerClassDic = dic
            return dic
        }
        
        set {
            objc_setAssociatedObject(self, &RegisterClassKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// 注册一种从Nib中加载的Cell
    func registerNibCell<T: NSView>(class type: T.Type) {
        let id = identifier(class: type)
        self.register(NSNib(nibNamed: id.rawValue, bundle: Bundle(for: T.self)), forIdentifier: id)
    }
    
    /// 注册一种代码创建的Cell
    func registerClassCell<T: NSView>(class type: T.Type) {
        let id = identifier(class: type)
        self.registerClassDic[id] = type
    }
    
    func dequeueReusableCell<T: NSView>(class type: T.Type) -> T {
        let id = identifier(class: type)
        if let cell = self.makeView(withIdentifier: id, owner: self) as? T {
            return cell
        }
        
        if let registerClass = self.registerClassDic[id] as? T.Type {
            let cell = registerClass.init(frame: .zero)
            cell.identifier = id
            return cell
        }
        
        return T()
    }
     
    private func identifier(class type: AnyClass) -> NSUserInterfaceItemIdentifier {
        let className = String(describing: type)
        return NSUserInterfaceItemIdentifier(rawValue: className)
    }
}
