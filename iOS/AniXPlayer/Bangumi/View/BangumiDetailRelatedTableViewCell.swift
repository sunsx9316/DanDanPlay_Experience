//
//  BangumiDetailRelatedTableViewCell.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/7.
//

import UIKit
import SnapKit
import Kingfisher

// MARK: - HorizontalAnimeCollectionViewCell

private class HorizontalAnimeCollectionViewCell: CollectionViewCell {

    private let posterSize = CGSize(width: 110, height: 150)

    private lazy var posterContainer: UIView = {
        let view = UIView()
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.15
        return view
    }()

    private lazy var posterImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = .placeholderColor
        return iv
    }()

    private lazy var ratingBadge: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 10)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 3
        label.layer.masksToBounds = true
        return label
    }()

    private lazy var titleLabel: Label = {
        let label = Label()
        label.numberOfLines = 3
        label.font = .ddp_small
        label.textAlignment = .center
        return label
    }()

    func update(item: BangumiIntro, ratingNumberFormatter: NumberFormatter) {
        if !item.imageUrl.isEmpty {
            posterImageView.kf.setImage(with: URL(string: item.imageUrl), placeholder: UIImage.placeholder)
        } else {
            posterImageView.image = UIImage.placeholder
        }
        titleLabel.text = item.animeTitle

        if let ratingText = ratingNumberFormatter.string(from: NSNumber(value: item.rating)) {
            ratingBadge.text = "  ⭐ " + ratingText + "  "
            ratingBadge.isHidden = false
        } else {
            ratingBadge.isHidden = true
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        posterContainer.addSubview(posterImageView)
        posterContainer.addSubview(ratingBadge)
        posterImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.size.equalTo(posterSize)
        }
        ratingBadge.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(3)
            make.bottom.equalToSuperview().offset(-3)
            make.height.equalTo(18)
        }

        let stack = UIStackView(arrangedSubviews: [posterContainer, titleLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .center

        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(5)
            make.leading.trailing.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview().offset(-5)
        }
        titleLabel.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - BangumiDetailRelatedTableViewCell

class BangumiDetailRelatedTableViewCell: TableViewCell {

    private let cellSize = CGSize(width: 130, height: 215)

    lazy var titleLabel: Label = {
        let label = Label()
        label.font = .ddp_large
        return label
    }()

    private lazy var collectionView: CollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .init(top: 8, left: 15, bottom: 8, right: 15)
        layout.itemSize = cellSize

        let cv = CollectionView(frame: .zero, collectionViewLayout: layout)
        cv.delegate = self
        cv.dataSource = self
        cv.showsHorizontalScrollIndicator = false
        cv.backgroundColor = .clear
        cv.registerClassCell(class: HorizontalAnimeCollectionViewCell.self)
        return cv
    }()

    private lazy var ratingNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.roundingMode = .halfEven
        return formatter
    }()

    var didSelectedAnimateCallBack: ((Int) -> Void)?

    var refreshDataCallBack: (() -> Void)?

    var bangumiIntros: [BangumiIntro]? {
        didSet {
            self.collectionView.reloadData()
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(titleLabel)
        contentView.addSubview(collectionView)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(15)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(cellSize.height + 16)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension BangumiDetailRelatedTableViewCell: UICollectionViewDelegate, UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return bangumiIntros?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(class: HorizontalAnimeCollectionViewCell.self, indexPath: indexPath)
        if let item = bangumiIntros?[indexPath.item] {
            cell.update(item: item, ratingNumberFormatter: ratingNumberFormatter)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if let animeId = bangumiIntros?[indexPath.item].animeId, animeId != 0 {
            didSelectedAnimateCallBack?(animeId)
        }
    }
}
