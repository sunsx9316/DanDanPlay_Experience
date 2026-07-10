//
//  FavoriteViewController.swift
//  AniXPlayer
//
//  tvOS 我的关注 — 瀑布流 + AnimeListCollectionViewCell 子类
//

import UIKit
import SnapKit

class FavoriteViewController: ViewController {

    private var dataSource: [UserFavoriteItem] = []

    private lazy var ratingNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.roundingMode = .halfEven
        return formatter
    }()

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
        cv.registerClassCell(class: FavoriteItemCollectionViewCell.self)
        return cv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("我的关注", comment: "")

        self.view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        loadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = collectionView
    }

    private func loadData() {
        FavoriteNetworkHandle.getFavoriteList { [weak self] response, error in
            guard let self = self else { return }
            if let items = response?.favorites {
                self.dataSource = items
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            }
        }
    }
}

extension FavoriteViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(class: FavoriteItemCollectionViewCell.self, indexPath: indexPath)
        cell.update(item: dataSource[indexPath.item], ratingNumberFormatter: ratingNumberFormatter)
        return cell
    }
}

extension FavoriteViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = dataSource[indexPath.item]
        let detailVC = BangumiDetailViewController(animateId: item.animeId)
        self.navigationController?.pushViewController(detailVC, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first else { return nil }
        guard indexPath.item < dataSource.count else { return nil }
        let item = dataSource[indexPath.item]
        let isFav = item.favoriteStatus == .favorited
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

extension FavoriteViewController: WaterfallLayoutDelegate {

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < dataSource.count else { return itemWidth * 0.65 }
        return AnimeListCollectionViewCell.estimatedHeight(for: dataSource[indexPath.item], width: itemWidth)
    }
}
