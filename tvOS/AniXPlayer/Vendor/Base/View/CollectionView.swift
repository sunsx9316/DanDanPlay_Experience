//
//  CollectionView.swift
//  AniXPlayer
//
//  tvOS CollectionView 基类 — 焦点相关配置 + 引导布局
//

import UIKit

class CollectionView: UICollectionView {

    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        self.setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    private func setup() {
        self.backgroundColor = .black
        self.remembersLastFocusedIndexPath = true
    }
}
