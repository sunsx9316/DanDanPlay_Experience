//
//  TimelineItemViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SnapKit
import JXCategoryView

extension TimelineItemViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSources?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let model = self.dataSources?[indexPath.item]
        
        let cell = collectionView.dequeueCell(class: TimelineItemCollectionViewCell.self, indexPath: indexPath)
        cell.update(item: model, ratingNumberFormatter: self.ratingNumberFormatter)
        return cell
    }
}

extension TimelineItemViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        switch self.scrollDirection {
        case .vertical:
            return CGSize(width: collectionView.bounds.size.width, height: 140)
        case .horizontal:
            return CGSize(width: collectionView.bounds.size.width * 0.8, height: collectionView.bounds.height - 10)
        @unknown default:
            return CGSize(width: collectionView.bounds.size.width, height: 140)
        }
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

extension TimelineItemViewController: JXCategoryListContentViewDelegate {
    func listView() -> UIView! {
        return self.view
    }
}

class TimelineItemViewController: ViewController {
    
    private lazy var collectionView: CollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .init(top: 5, left: 0, bottom: 5, right: 0)
        layout.scrollDirection = self.scrollDirection
        
        let collectionView = CollectionView(frame: self.view.bounds, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = false
        collectionView.registerNibCell(class: TimelineItemCollectionViewCell.self)
        return collectionView
    }()
    
    private lazy var ratingNumberFormatter: NumberFormatter = {
        var ratingNumberFormatter = NumberFormatter()
        ratingNumberFormatter.numberStyle = .decimal
        ratingNumberFormatter.minimumFractionDigits = 1
        ratingNumberFormatter.roundingMode = .halfEven
        return ratingNumberFormatter
    }()
    
    var dataSources: [BangumiIntro]? {
        didSet {
            self.collectionView.reloadData()
        }
    }
    
    var didSelectedAnimateCallBack: ((Int) -> Void)?
    
    private var scrollDirection = UICollectionView.ScrollDirection.vertical
    
    init(scrollDirection: UICollectionView.ScrollDirection, dataSources: [BangumiIntro]?) {
        super.init(nibName: nil, bundle: nil)
        
        self.dataSources = dataSources
        self.scrollDirection = scrollDirection
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
        
        self.collectionView.reloadData()
    }
}
