//
//  UICollectionView+Helper.swift
//  AniXPlayer
//
//  UICollectionView 注册/复用便捷扩展 — 自动以类名作为 reuseIdentifier
//

#if os(iOS) || os(tvOS)
import UIKit

extension UICollectionView {

    // MARK: Cell

    /// 注册一种从 Nib 中加载的 Cell
    func registerNibCell<T: UICollectionViewCell>(class type: T.Type) {
        let className = String(describing: type)
        self.register(UINib(nibName: className, bundle: .init(for: type)), forCellWithReuseIdentifier: className)
    }

    /// 注册一种代码创建的 Cell
    func registerClassCell<T: UICollectionViewCell>(class type: T.Type) {
        let className = String(describing: type)
        self.register(type, forCellWithReuseIdentifier: className)
    }

    /// 获取一个 Cell
    func dequeueCell<T: UICollectionViewCell>(class type: T.Type, indexPath: IndexPath) -> T {
        return self.dequeueReusableCell(withReuseIdentifier: String(describing: type), for: indexPath) as! T
    }

    // MARK: SupplementaryView

    /// 注册一种 SupplementaryView
    func registerSupplementaryView<T: UICollectionReusableView>(class type: T.Type, kind: String) {
        self.register(type, forSupplementaryViewOfKind: kind, withReuseIdentifier: String(describing: type))
    }

    /// 获取一种 SupplementaryView
    func dequeueSupplementaryView<T: UICollectionReusableView>(class type: T.Type, kind: String, indexPath: IndexPath) -> T {
        return self.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: String(describing: type), for: indexPath) as! T
    }
}
#endif
