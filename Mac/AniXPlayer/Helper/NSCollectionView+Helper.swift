//
//  NSCollectionView+Helper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/30.
//

import Cocoa

extension NSCollectionView {

    private static func identifier<T: NSCollectionViewItem>(for type: T.Type) -> NSUserInterfaceItemIdentifier {
        return NSUserInterfaceItemIdentifier(String(describing: type))
    }

    func registerItem<T: NSCollectionViewItem>(class type: T.Type) {
        register(type, forItemWithIdentifier: Self.identifier(for: type))
    }

    func dequeueItem<T: NSCollectionViewItem>(class type: T.Type, for indexPath: IndexPath) -> T {
        return makeItem(withIdentifier: Self.identifier(for: type), for: indexPath) as! T
    }
}
