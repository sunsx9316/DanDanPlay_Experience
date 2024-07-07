//
//  CollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit

class CollectionViewCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInit()
    }
    
    private func setupInit() {
        self.selectedBackgroundView = UIView()
        self.selectedBackgroundView?.backgroundColor = .cellHighlightColor
        self.backgroundView = .init()
        self.backgroundView?.backgroundColor = .backgroundColor
        self.backgroundColor = .clear
    }

}
