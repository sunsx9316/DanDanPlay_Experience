//
//  CollectionView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit

class CollectionView: UICollectionView {
    
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    private func setupInit() {
        self.backgroundColor = .backgroundColor
        self.contentInsetAdjustmentBehavior = .automatic
    }
}
