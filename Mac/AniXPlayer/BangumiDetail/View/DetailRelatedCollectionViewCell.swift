//
//  DetailRelatedCollectionViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/29.
//

import Cocoa
import SnapKit

class DetailRelatedCollectionViewCell: CollectionViewItem, NSCollectionViewDataSource, NSCollectionViewDelegate, WaterfallLayoutDelegate {

    var onSelectAnime: ((Int) -> Void)?
    var onFavoriteToggle: ((Int, Bool) -> Void)?

    private var items: [BangumiIntro] = []

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .ddp_normal(weight: .bold)
        tf.textColor = .textColor
        return tf
    }()

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 2
        layout.delegate = self
        return layout
    }()

    private lazy var innerCollectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = waterfallLayout
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.backgroundColor]
        cv.isSelectable = true
        cv.frame = NSRect(x: 0, y: 0, width: 600, height: 180)
        cv.registerItem(class: RelatedAnimeCollectionViewCell.self)
        return cv
    }()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(titleLabel)
        view.addSubview(innerCollectionView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-20)
        }

        innerCollectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }
    }

    func configure(title: String, items: [BangumiIntro]) {
        titleLabel.text = title
        self.items = items
        innerCollectionView.reloadData()
        innerCollectionView.layoutSubtreeIfNeeded()
        let contentSize = waterfallLayout.collectionViewContentSize
        innerCollectionView.frame.size = NSSize(
            width: view.bounds.width,
            height: max(contentSize.height, 180)
        )
    }

    static func estimatedHeight(for items: [BangumiIntro], width: CGFloat) -> CGFloat {
        guard !items.isEmpty else { return 0 }

        let layout = WaterfallLayout()
        layout.columnCount = 2
        let availableWidth = width - layout.sectionInset.left - layout.sectionInset.right
        let itemWidth = (availableWidth - layout.itemPadding * CGFloat(layout.columnCount - 1)) / CGFloat(layout.columnCount)

        var columnHeights = Array(repeating: layout.sectionInset.top, count: layout.columnCount)
        for item in items {
            let column = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let height = RelatedAnimeCollectionViewCell.estimatedHeight(for: item, width: itemWidth)
            columnHeights[column] = columnHeights[column] + height + layout.itemPadding
        }
        let waterfallHeight = (columnHeights.max() ?? layout.sectionInset.top) + layout.sectionInset.bottom
        return 18 + 8 + waterfallHeight
    }

    // MARK: - NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.dequeueItem(class: RelatedAnimeCollectionViewCell.self, for: indexPath)
        let model = items[indexPath.item]
        item.configure(with: model)
        item.onFavoriteToggle = { [weak self] animeId, isLike in
            self?.onFavoriteToggle?(animeId, isLike)
        }
        return item
    }

    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        collectionView.deselectItems(at: indexPaths)
        guard let indexPath = indexPaths.first,
              indexPath.item < items.count else { return }
        onSelectAnime?(items[indexPath.item].animeId)
    }

    // MARK: - WaterfallLayoutDelegate

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < items.count else { return itemWidth * 1.6 }
        return RelatedAnimeCollectionViewCell.estimatedHeight(for: items[indexPath.item], width: itemWidth)
    }
}
