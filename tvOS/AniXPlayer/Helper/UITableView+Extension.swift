//
//  UITableView+Extension.swift
//  AniXPlayer
//
//  tvOS UITableView 注册/复用便捷扩展 — 自动以类名作为 reuseIdentifier
//

import UIKit

extension UITableView {

    func registerClassCell<T: UITableViewCell>(class type: T.Type) {
        self.register(type, forCellReuseIdentifier: String(describing: type))
    }

    func dequeueCell<T: UITableViewCell>(class type: T.Type, indexPath: IndexPath) -> T {
        return self.dequeueReusableCell(withIdentifier: String(describing: type), for: indexPath) as! T
    }
}
