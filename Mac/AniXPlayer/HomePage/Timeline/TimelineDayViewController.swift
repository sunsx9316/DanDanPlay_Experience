//
//  TimelineDayViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/11.
//

import Cocoa
import SnapKit

/// 展示某一天的番剧列表，瀑布流
class TimelineDayViewController: ViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, WaterfallLayoutDelegate {

    var items: [BangumiIntro] = [] {
        didSet {
            guard isViewLoaded else { return }
            waterfallLayout.invalidateLayout()
            collectionView.reloadData()
            collectionView.layoutSubtreeIfNeeded()
            updateCollectionFrame()
        }
    }

    var onFavoriteToggle: ((Int, Bool) -> Void)?

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 2
        layout.delegate = self
        return layout
    }()

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView()
        cv.collectionViewLayout = waterfallLayout
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColors = [.backgroundColor]
        cv.isSelectable = true
        cv.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        cv.registerItem(class: TimelineCollectionViewCell.self)
        return cv
    }()

    private lazy var scrollView: ScrollView<CollectionView> = {
        let sv = ScrollView<CollectionView>()
        sv.containerView = collectionView
        sv.hasVerticalScroller = true
        sv.borderType = .noBorder
        sv.drawsBackground = false
        return sv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateCollectionFrame()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateCollectionFrame()
    }

    private func updateCollectionFrame() {
        let w = scrollView.contentView.bounds.width
        guard w > 0 else { return }
        collectionView.frame.size.width = w
        collectionView.layoutSubtreeIfNeeded()
        let h = waterfallLayout.collectionViewContentSize.height
        collectionView.frame.size.height = max(h, scrollView.contentView.bounds.height)
    }

    // MARK: - NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.dequeueItem(class: TimelineCollectionViewCell.self, for: indexPath)
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
        guard let indexPath = indexPaths.first, indexPath.item < items.count else { return }
        let vc = BangumiDetailViewController(animateId: items[indexPath.item].animeId)
        navigator?.pushViewController(vc)
    }

    // MARK: - WaterfallLayoutDelegate

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < items.count else { return itemWidth * 1.6 }
        let m = items[indexPath.item]
        let ih = itemWidth * 1.4
        let th = m.animeTitle.boundingRect(
            with: NSSize(width: itemWidth - 16, height: 40),
            options: .usesLineFragmentOrigin,
            attributes: [.font: NSFont.ddp_normal()]
        ).height.rounded(.up)
        return 4 + ih + 4 + th + 4 + 20 + 4 + 8
    }
}
