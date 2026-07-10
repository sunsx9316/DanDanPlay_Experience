//
//  UITableView+Helper.swift
//  AniXPlayer
//
//  UITableView 注册/复用便捷扩展 — 自动以类名作为 reuseIdentifier
//

#if os(iOS) || os(tvOS)
import UIKit

extension UITableView {

    // MARK: Cell

    /// 注册一种从 Nib 中加载的 Cell
    func registerNibCell<T: UITableViewCell>(class type: T.Type) {
        let className = String(describing: type)
        self.register(UINib(nibName: className, bundle: .init(for: type)), forCellReuseIdentifier: className)
    }

    /// 注册一种代码创建的 Cell
    func registerClassCell<T: UITableViewCell>(class type: T.Type) {
        let className = String(describing: type)
        self.register(type, forCellReuseIdentifier: className)
    }

    /// 获取一个 Cell
    func dequeueCell<T: UITableViewCell>(class type: T.Type, indexPath: IndexPath) -> T {
        return self.dequeueReusableCell(withIdentifier: String(describing: type), for: indexPath) as! T
    }

    // MARK: HeaderFooterView

    /// 注册一种代码创建的 HeaderFooterView（简明别名）
    func registerHeaderFooterView<T: UITableViewHeaderFooterView>(class type: T.Type) {
        registerClassHeaderFooterView(class: type)
    }

    /// 注册一种从 Nib 中加载的 HeaderFooterView
    func registerNibHeaderFooterView<T: UITableViewHeaderFooterView>(class type: T.Type) {
        let className = String(describing: type)
        self.register(UINib(nibName: className, bundle: .init(for: type)), forHeaderFooterViewReuseIdentifier: className)
    }

    /// 注册一种代码创建的 HeaderFooterView
    func registerClassHeaderFooterView<T: UITableViewHeaderFooterView>(class type: T.Type) {
        let className = String(describing: type)
        self.register(type, forHeaderFooterViewReuseIdentifier: className)
    }

    /// 获取一个 HeaderFooterView
    func dequeueHeaderFooterView<T: UITableViewHeaderFooterView>(class type: T.Type) -> T {
        let identifier = String(describing: type)
        return self.dequeueReusableHeaderFooterView(withIdentifier: identifier) as! T
    }
}
#endif
