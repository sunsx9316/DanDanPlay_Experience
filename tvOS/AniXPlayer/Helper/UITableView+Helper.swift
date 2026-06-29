//
//  UITableView+Helper.swift
//  AniXPlayer
//
//  tvOS UITableView 注册/复用便捷扩展 — 自动以类名作为 reuseIdentifier
//

import UIKit

extension UITableView {

    // MARK: Cell

    func registerClassCell<T: UITableViewCell>(class type: T.Type) {
        self.register(type, forCellReuseIdentifier: String(describing: type))
    }

    func dequeueCell<T: UITableViewCell>(class type: T.Type, indexPath: IndexPath) -> T {
        return self.dequeueReusableCell(withIdentifier: String(describing: type), for: indexPath) as! T
    }

    // MARK: HeaderFooterView

    func registerHeaderFooterView<T: UITableViewHeaderFooterView>(class type: T.Type) {
        self.register(type, forHeaderFooterViewReuseIdentifier: String(describing: type))
    }

    func dequeueHeaderFooterView<T: UITableViewHeaderFooterView>(class type: T.Type) -> T? {
        return self.dequeueReusableHeaderFooterView(withIdentifier: String(describing: type)) as? T
    }
}
