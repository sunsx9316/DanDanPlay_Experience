//
//  FavoriteViewController.swift
//  AniXPlayer
//
//  tvOS 我的关注 — 瀑布流
//

import UIKit
import SnapKit

class FavoriteViewController: ViewController {

    private var dataSource: [UserFavoriteItem] = []

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 3
        layout.sectionInset = UIEdgeInsets(top: 40, left: 60, bottom: 20, right: 60)
        layout.itemPadding = 16
        layout.delegate = self
        return layout
    }()

    private lazy var collectionView: CollectionView = {
        let cv = CollectionView(frame: .zero, collectionViewLayout: waterfallLayout)
        cv.delegate = self
        cv.dataSource = self
        cv.registerClassCell(class: FavoriteItemCell.self)
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
        let cell = collectionView.dequeueCell(class: FavoriteItemCell.self, indexPath: indexPath)
        cell.configure(with: dataSource[indexPath.item])
        return cell
    }
}

extension FavoriteViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = dataSource[indexPath.item]
        let detailVC = BangumiDetailViewController(animateId: item.animeId)
        self.navigationController?.pushViewController(detailVC, animated: true)
    }
}

extension FavoriteViewController: WaterfallLayoutDelegate {

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < dataSource.count else { return itemWidth * 0.65 }
        return FavoriteItemCell.estimatedHeight(for: dataSource[indexPath.item], width: itemWidth)
    }
}
