//
//  UICollectionView+Helper.swift
//  AniXPlayer
//
//  tvOS UICollectionView 注册/复用便捷扩展 — 自动以类名作为 reuseIdentifier
//

import UIKit

extension UICollectionView {

    func registerClassCell<T: UICollectionViewCell>(class type: T.Type) {
        self.register(type, forCellWithReuseIdentifier: String(describing: type))
    }

    func dequeueCell<T: UICollectionViewCell>(class type: T.Type, indexPath: IndexPath) -> T {
        return self.dequeueReusableCell(withReuseIdentifier: String(describing: type), for: indexPath) as! T
    }

    func registerSupplementaryView<T: UICollectionReusableView>(class type: T.Type, kind: String) {
        self.register(type, forSupplementaryViewOfKind: kind, withReuseIdentifier: String(describing: type))
    }

    func dequeueSupplementaryView<T: UICollectionReusableView>(class type: T.Type, kind: String, indexPath: IndexPath) -> T {
        return self.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: String(describing: type), for: indexPath) as! T
    }
}
