//
//  CollectionViewItem.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/1.
//

import Cocoa

class CollectionViewItem: NSCollectionViewItem {

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
