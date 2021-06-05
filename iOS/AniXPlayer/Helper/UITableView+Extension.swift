//
//  UITableView+Extension.swift
//  Runner
//
//  Created by jimhuang on 2021/3/7.
//

import UIKit

extension UITableView {
    
    /// 注册一种从Nib中加载的Cell
    /// ReuseIdentifier为类名
    /// nibName为类名
    func registerNibCell<T: UITableViewCell>(class type: T.Type) {
        let className = String(describing: type)
        self.register(UINib(nibName: className, bundle: .init(for: type)), forCellReuseIdentifier: className)
    }
    /// 注册一种代码创建的Cell
    /// ReuseIdentifier为类名
    ///
    func registerClassCell<T: UITableViewCell>(class type: T.Type) {
        let className = String(describing: type)
        self.register(type, forCellReuseIdentifier: className)
    }
    
    /// 获取一个Cell
    /// ReuseIdentifier为类名
    ///
    func dequeueCell<T: UITableViewCell>(class type: T.Type, indexPath: IndexPath) -> T {
        return self.dequeueReusableCell(withIdentifier: String(describing: type), for: indexPath) as! T
    }
    
    func registerNibHeaderFooterView<T: UITableViewHeaderFooterView>(class type: T.Type) {
        let className = String(describing: type)
        self.register(UINib(nibName: className, bundle: nil), forHeaderFooterViewReuseIdentifier: className)
    }
    
    func registerClassHeaderFooterView<T: UITableViewHeaderFooterView>(class type: T.Type) {
        let className = String(describing: type)
        self.register(type, forHeaderFooterViewReuseIdentifier: className)
    }
    
    func dequeueHeaderFooterView<T: UITableViewHeaderFooterView>(class type: T.Type) -> T {
        let identifier = String(describing: type)
        return self.dequeueReusableHeaderFooterView(withIdentifier: identifier) as! T
    }
}
