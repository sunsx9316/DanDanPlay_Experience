//
//  HomePageFunctionTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import UIKit
import SVGKit
import SnapKit

extension HomePageFunctionTableViewCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueCell(class: HomePageFunctionCollectionViewCell.self, indexPath: indexPath)
        cell.item = self.dataSource[indexPath.item]
        return cell
    }
}

extension HomePageFunctionTableViewCell: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 100, height: collectionView.bounds.height - 10)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let item = self.dataSource[indexPath.item]
        self.didSelectedItemCallBack?(item.itemType)
    }
}

class HomePageFunctionTableViewCell: TableViewCell {
    
    private lazy var dataSource: [HomePageFunctionItem] = {
        var dataSource = [HomePageFunctionItem]()
        if let svgImage = SVGKImage(named: "Timeline.svg") {
            svgImage.size = CGSize(width: 60, height: 60)
            dataSource.append(.init(itemType: .timeLine, img: svgImage.uiImage, name: NSLocalizedString("新番时间表", comment: "")))
        }
        
        return dataSource
    }()

    private lazy var collectionView: CollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .init(top: 5, left: 0, bottom: 5, right: 0)
        layout.scrollDirection = .horizontal
        let collectionView = CollectionView(frame: self.contentView.bounds, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.registerNibCell(class: HomePageFunctionCollectionViewCell.self)
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        return collectionView
    }()
    
    var didSelectedItemCallBack: ((HomePageFunctionItem.ItemType) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInit()
    }
    
    // MARK: Private
    
    private func setupInit() {
        self.contentView.addSubview(self.collectionView)
        
        self.collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
    }
    
}
