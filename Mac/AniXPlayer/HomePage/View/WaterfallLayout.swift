//
//  WaterfallLayout.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/1.
//

import Cocoa

protocol WaterfallLayoutDelegate: AnyObject {
    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat
}

class WaterfallLayout: NSCollectionViewLayout {

    enum LayoutMode {
        /// 按当前最短列放置，保留原有瀑布流页面的行为。
        case waterfall
        /// 按阅读顺序逐行放置；同一行顶部对齐，末行始终从左侧开始。
        case grid
    }

    var mode: LayoutMode = .waterfall {
        didSet { invalidateLayout() }
    }

    var columnCount: Int = 2 {
        didSet { invalidateLayout() }
    }

    var itemPadding: CGFloat = 8 {
        didSet { invalidateLayout() }
    }

    var sectionInset: NSEdgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12) {
        didSet { invalidateLayout() }
    }

    weak var delegate: WaterfallLayoutDelegate?

    private var layoutAttributes: [NSCollectionViewLayoutAttributes] = []
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

        switch mode {
        case .waterfall:
            prepareWaterfall(
                itemCount: itemCount,
                itemWidth: itemWidth,
                delegate: delegate
            )
        case .grid:
            prepareGrid(
                itemCount: itemCount,
                itemWidth: itemWidth,
                delegate: delegate
            )
        }
    }

    override var collectionViewContentSize: NSSize {
        guard let collectionView = collectionView else { return .zero }
        return NSSize(width: collectionView.bounds.width, height: max(contentHeight, collectionView.bounds.height))
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        return layoutAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        return layoutAttributes.first { $0.indexPath == indexPath }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }

    private func prepareWaterfall(
        itemCount: Int,
        itemWidth: CGFloat,
        delegate: WaterfallLayoutDelegate
    ) {
        var columnHeights = Array(repeating: sectionInset.top, count: columnCount)
        var attributes: [NSCollectionViewLayoutAttributes] = []

        for i in 0..<itemCount {
            let indexPath = IndexPath(item: i, section: 0)
            let column = shortestColumnIndex(columnHeights)
            let x = sectionInset.left + (itemWidth + itemPadding) * CGFloat(column)
            let y = columnHeights[column]
            let height = delegate.waterfallLayout(self, heightForItemAt: indexPath, itemWidth: itemWidth)

            let attr = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
            attr.frame = NSRect(x: x, y: y, width: itemWidth, height: height)
            attributes.append(attr)

            columnHeights[column] = y + height + itemPadding
        }

        layoutAttributes = attributes
        contentHeight = (columnHeights.max() ?? sectionInset.top) + sectionInset.bottom
    }

    private func prepareGrid(
        itemCount: Int,
        itemWidth: CGFloat,
        delegate: WaterfallLayoutDelegate
    ) {
        var attributes: [NSCollectionViewLayoutAttributes] = []
        var y = sectionInset.top
        var rowHeight: CGFloat = 0

        for i in 0..<itemCount {
            let indexPath = IndexPath(item: i, section: 0)
            let column = i % columnCount
            let height = delegate.waterfallLayout(self, heightForItemAt: indexPath, itemWidth: itemWidth)
            let x = sectionInset.left + (itemWidth + itemPadding) * CGFloat(column)

            let attr = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
            attr.frame = NSRect(x: x, y: y, width: itemWidth, height: height)
            attributes.append(attr)
            rowHeight = max(rowHeight, height)

            let isRowEnd = column == columnCount - 1 || i == itemCount - 1
            if isRowEnd {
                y += rowHeight + itemPadding
                rowHeight = 0
            }
        }

        layoutAttributes = attributes
        contentHeight = y + sectionInset.bottom
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
