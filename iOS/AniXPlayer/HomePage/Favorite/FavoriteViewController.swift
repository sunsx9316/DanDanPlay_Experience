//
//  FavoriteViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SnapKit
import MJRefresh

extension FavoriteViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSources?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let model = self.dataSources?[indexPath.item]
        
        let cell = collectionView.dequeueCell(class: FavoriteCollectionViewCell.self, indexPath: indexPath)
        cell.update(item: model, ratingNumberFormatter: self.ratingNumberFormatter, dateFormatter: self.dateFormatter)
        cell.didTouchLikeButton = { [weak self] (aCell, isLike) in
            guard let animeId = aCell.item?.animeId else { return }
            
            aCell.favoritedButton.isUserInteractionEnabled = false
            
            FavoriteNetworkHandle.changeFavorite(animateId: animeId, isLike: isLike) { [weak self, weak aCell] error in
                guard let self = self, let aCell = aCell else { return }
                
                DispatchQueue.main.async {
                    aCell.favoritedButton.isUserInteractionEnabled = true
                    if let error = error {
                        self.view.showError(error)
                    } else {
                        aCell.item?.favoriteStatus = isLike ? .favorited : .unknow
                    }
                }
            }
        }
        return cell
    }
}

extension FavoriteViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.size.width, height: 140)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let model = self.dataSources?[indexPath.item]
        
        if let animeId = model?.animeId, animeId != 0 {
            let vc = BangumiDetailViewController(animateId: animeId)
            self.navigationController?.pushViewController(vc, animated: true)
            self.didSelectedAnimateCallBack?(animeId)
        }
    }
}

class FavoriteViewController: ViewController {
    
    private lazy var collectionView: CollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .init(top: 5, left: 0, bottom: 5, right: 0)
        layout.scrollDirection = .vertical
        
        let collectionView = CollectionView(frame: self.view.bounds, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = false
        collectionView.registerNibCell(class: FavoriteCollectionViewCell.self)
        collectionView.mj_header = RefreshHeader(refreshingTarget: self, refreshingAction: #selector(startRefresh))
        return collectionView
    }()
    
    @objc private func startRefresh() {
        FavoriteNetworkHandle.getFavoriteList { res, error in
            DispatchQueue.main.async {
                self.collectionView.mj_header?.endRefreshing()
                if let error = error {
                    self.view.showError(error)
                } else {
                    self.dataSources = res?.favorites
                }
            }
        }
    }
    
    private lazy var ratingNumberFormatter: NumberFormatter = {
        var ratingNumberFormatter = NumberFormatter()
        ratingNumberFormatter.numberStyle = .decimal
        ratingNumberFormatter.minimumFractionDigits = 1
        ratingNumberFormatter.roundingMode = .halfEven
        return ratingNumberFormatter
    }()
    
    private lazy var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        return dateFormatter
    }()
    
    var dataSources: [UserFavoriteItem]? {
        didSet {
            self.collectionView.reloadData()
        }
    }
    
    var didSelectedAnimateCallBack: ((Int) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("我的关注", comment: "")
        
        self.view.addSubview(self.collectionView)
        self.collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.collectionView.reloadData()
        self.collectionView.mj_header?.beginRefreshing()
    }
}
