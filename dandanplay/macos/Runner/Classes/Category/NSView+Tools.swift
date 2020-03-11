//
//  NSView+Tools.swift
//  Runner
//
//  Created by JimHuang on 2020/3/8.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation

extension NSTableView {
    func dequeueReusableCell<T: NSView>(withCellClass cellClass: T.Type) -> T {
        let id = NSUserInterfaceItemIdentifier("\(cellClass.self)")
        if let cell = self.makeView(withIdentifier: id, owner: self) as? T {
            return cell
        }
        
        let cell = cellClass.init(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.rowHeight))
        cell.identifier = id
        return cell
    }
    
    func dequeueReusableCell<T: NSView>(withNibClass nibClass: T.Type) -> T {
        let id = NSUserInterfaceItemIdentifier("\(nibClass.self)")
        if let cell = self.makeView(withIdentifier: id, owner: self) as? T {
            return cell
        }
        
        let cell = nibClass.loadFromNib()
        cell.identifier = id
        return cell
    }
}
