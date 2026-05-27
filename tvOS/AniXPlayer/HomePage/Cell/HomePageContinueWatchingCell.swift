//
//  HomePageContinueWatchingCell.swift
//  AniXPlayer
//
//  tvOS 首页"继续播放" — TableViewCell 内嵌水平 CollectionView
//

import UIKit
import SnapKit
import Kingfisher

class HomePageContinueWatchingCell: TableViewCell {

    static let reuseIdentifier = "HomePageContinueWatchingCell"

    var items: [BangumiQueueIntro] = [] {
        didSet {
            collectionView.reloadData()
            titleLabel.isHidden = items.isEmpty
        }
    }

    var onItemSelected: ((BangumiQueueIntro) -> Void)?

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .ddp_small(weight: .bold)
        label.textColor = .white
        label.text = NSLocalizedString("继续播放", comment: "")
        return label
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 60)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(PosterItemCell.self, forCellWithReuseIdentifier: PosterItemCell.reuseIdentifier)
        return cv
    }()

    override var canBecomeFocused: Bool { return false }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return items.isEmpty ? [] : [collectionView]
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none

        contentView.addSubview(titleLabel)
        contentView.addSubview(collectionView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(60)
            make.top.equalToSuperview().offset(10)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(210)
            make.bottom.equalToSuperview().offset(-10)
        }
    }
}

// MARK: - PosterItemCell

extension HomePageContinueWatchingCell {

    class PosterItemCell: CollectionViewCell {
        static let reuseIdentifier = "PosterItemCell"

        private lazy var posterImageView: UIImageView = {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 8
            iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            iv.adjustsImageWhenAncestorFocused = true
            return iv
        }()

        private lazy var nameLabel: UILabel = {
            let label = UILabel()
            label.font = .ddp_small(weight: .medium)
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 2
            return label
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.addSubview(posterImageView)
            contentView.addSubview(nameLabel)

            posterImageView.snp.makeConstraints { make in
                make.top.centerX.equalToSuperview()
                make.width.equalToSuperview()
                make.height.equalTo(posterImageView.snp.width).multipliedBy(9.0 / 16.0)
            }

            nameLabel.snp.makeConstraints { make in
                make.top.equalTo(posterImageView.snp.bottom).offset(10)
                make.leading.trailing.equalToSuperview().inset(8)
            }
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        func configure(with item: BangumiQueueIntro) {
            nameLabel.text = item.animeTitle
            if let url = URL(string: item.imageUrl) {
                posterImageView.kf.setImage(with: url)
            }
        }
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension HomePageContinueWatchingCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PosterItemCell.reuseIdentifier, for: indexPath) as! PosterItemCell
        cell.configure(with: items[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 240, height: 200)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onItemSelected?(items[indexPath.item])
    }
}
