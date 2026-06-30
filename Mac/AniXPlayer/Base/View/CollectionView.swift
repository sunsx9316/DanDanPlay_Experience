//
//  CollectionView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/1.
//

import Cocoa

class CollectionView: NSCollectionView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColors = [.clear]
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColors = [.clear]
    }
}
