//
//  UICollectionView+Helper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import Foundation

extension UICollectionView {
    
    /// 注册一种从Nib中加载的Cell
    /// ReuseIdentifier为类名
    /// nibName为类名
    func registerNibCell<T: UICollectionViewCell>(class type: T.Type) {
        let className = String(describing: type)
        self.register(UINib(nibName: className, bundle: .init(for: type)), forCellWithReuseIdentifier: className)
    }
    /// 注册一种代码创建的Cell
    /// ReuseIdentifier为类名
    ///
    func registerClassCell<T: UICollectionViewCell>(class type: T.Type) {
        let className = String(describing: type)
        self.register(type, forCellWithReuseIdentifier: className)
    }
    
    /// 获取一个Cell
    /// ReuseIdentifier为类名
    ///
    func dequeueCell<T: UICollectionViewCell>(class type: T.Type, indexPath: IndexPath) -> T {
        return self.dequeueReusableCell(withReuseIdentifier: String(describing: type), for: indexPath) as! T
    }
}
