//
//  FavoriteViewController.swift
//  AniXPlayer
//
//  tvOS 我的关注
//

import UIKit
import SnapKit

class FavoriteViewController: ViewController {

    private var dataSource: [UserFavoriteItem] = []

    private lazy var collectionView: CollectionView = {
        let layout = Self.createLayout()
        let cv = CollectionView(frame: .zero, collectionViewLayout: layout)
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

    private static func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(100))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 40, leading: 60, bottom: 20, trailing: 60)

        return UICollectionViewCompositionalLayout(section: section)
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
