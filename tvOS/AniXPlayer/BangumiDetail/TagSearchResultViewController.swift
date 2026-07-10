//
//  TagSearchResultViewController.swift
//  AniXPlayer
//
//  tvOS Tag 搜索结果页 — 瀑布流 CollectionView + AnimeListCollectionViewCell
//

import UIKit
import SnapKit

extension SearchBangumiDetails: AnimeListItem {
    var hasRating: Bool { true }
}

class TagSearchResultViewController: ViewController {

    private let tag: String

    private var items: [SearchBangumiDetails] = []

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 3
        layout.sectionInset = UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60)
        layout.itemPadding = 40
        layout.delegate = self
        return layout
    }()

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView(frame: .zero, collectionViewLayout: waterfallLayout)
        cv.delegate = self
        cv.dataSource = self
        cv.registerClassCell(class: AnimeListCollectionViewCell.self)
        return cv
    }()

    private lazy var ratingNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.roundingMode = .halfEven
        return formatter
    }()

    init(tag: String) {
        self.tag = tag
        super.init(nibName: nil, bundle: nil)
        self.title = tag
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.collectionView)
        self.collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = collectionView
    }

    private func loadData() {
        SearchNetworkHandle.searchByTag(self.tag) { [weak self] res, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let error = error {
                    self.view.showError(error)
                } else {
                    self.items = res?.bangumis ?? []
                    self.collectionView.reloadData()
                }
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension TagSearchResultViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(class: AnimeListCollectionViewCell.self, indexPath: indexPath)
        cell.update(item: items[indexPath.item], ratingNumberFormatter: ratingNumberFormatter)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension TagSearchResultViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        let vc = BangumiDetailViewController(animateId: item.animeId)
        self.navigationController?.pushViewController(vc, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first else { return nil }
        guard indexPath.item < items.count else { return nil }
        let item = items[indexPath.item]
        let isFav = item.isFavorited
        let title = isFav ? NSLocalizedString("取消关注", comment: "") : NSLocalizedString("关注", comment: "")

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let action = UIAction(title: title, image: nil) { [weak self] _ in
                guard let self = self else { return }
                FavoriteNetworkHandle.changeFavorite(animateId: item.animeId, isLike: !isFav) { [weak self] error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.view.showError(error)
                        }
                    }
                }
            }
            return UIMenu(title: "", children: [action])
        }
    }
}

// MARK: - WaterfallLayoutDelegate

extension TagSearchResultViewController: WaterfallLayoutDelegate {

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < items.count else { return itemWidth * 0.65 }
        return AnimeListCollectionViewCell.estimatedHeight(for: items[indexPath.item], width: itemWidth)
    }
}
