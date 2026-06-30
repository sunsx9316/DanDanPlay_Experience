//
//  WaterfallLayout.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/1.
//

import UIKit

protocol WaterfallLayoutDelegate: AnyObject {
    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat
}

class WaterfallLayout: UICollectionViewLayout {

    var columnCount: Int = 2 {
        didSet { invalidateLayout() }
    }

    var itemPadding: CGFloat = 8 {
        didSet { invalidateLayout() }
    }

    var sectionInset: UIEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12) {
        didSet { invalidateLayout() }
    }

    weak var delegate: WaterfallLayoutDelegate?

    private var layoutAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    override func prepare() {
        super.prepare()

        guard let collectionView = collectionView,
              let delegate = delegate else {
            layoutAttributes = []
            contentHeight = 0
            return
        }

        let itemCount = collectionView.numberOfItems(inSection: 0)
        guard itemCount > 0 else {
            layoutAttributes = []
            contentHeight = 0
            return
        }

        let availableWidth = collectionView.bounds.width - sectionInset.left - sectionInset.right
        let totalPadding = itemPadding * CGFloat(columnCount - 1)
        let itemWidth = (availableWidth - totalPadding) / CGFloat(columnCount)

        var columnHeights = Array(repeating: sectionInset.top, count: columnCount)
        var attributes: [UICollectionViewLayoutAttributes] = []

        for i in 0..<itemCount {
            let indexPath = IndexPath(item: i, section: 0)
            let column = shortestColumnIndex(columnHeights)
            let x = sectionInset.left + (itemWidth + itemPadding) * CGFloat(column)
            let y = columnHeights[column]
            let height = delegate.waterfallLayout(self, heightForItemAt: indexPath, itemWidth: itemWidth)

            let attr = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attr.frame = CGRect(x: x, y: y, width: itemWidth, height: height)
            attributes.append(attr)

            columnHeights[column] = y + height + itemPadding
        }

        layoutAttributes = attributes
        contentHeight = (columnHeights.max() ?? sectionInset.top) + sectionInset.bottom
    }

    override var collectionViewContentSize: CGSize {
        guard let collectionView = collectionView else { return .zero }
        return CGSize(width: collectionView.bounds.width, height: max(contentHeight, collectionView.bounds.height))
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return layoutAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return layoutAttributes.first { $0.indexPath == indexPath }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }

    private func shortestColumnIndex(_ heights: [CGFloat]) -> Int {
        var minIndex = 0
        var minHeight = heights[0]
        for i in 1..<heights.count {
            if heights[i] < minHeight {
                minHeight = heights[i]
                minIndex = i
            }
        }
        return minIndex
    }
}
