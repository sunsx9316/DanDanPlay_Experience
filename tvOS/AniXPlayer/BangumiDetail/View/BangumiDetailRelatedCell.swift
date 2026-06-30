//
//  BangumiDetailRelatedCell.swift
//  AniXPlayer
//
//  tvOS 番剧详情关联/相似作品 — TableViewCell 内嵌瀑布流 CollectionView
//

import UIKit
import SnapKit
import Kingfisher

class BangumiDetailRelatedCell: TableViewCell {

    var items: [BangumiIntro] = [] {
        didSet {
            collectionView.reloadData()
            updateCollectionViewHeight()
        }
    }

    var onItemSelected: ((Int) -> Void)?

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .ddp_large()
        label.textColor = .white
        return label
    }()

    private lazy var waterfallLayout: WaterfallLayout = {
        let layout = WaterfallLayout()
        layout.columnCount = 3
        layout.delegate = self
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: waterfallLayout)
        cv.backgroundColor = .clear
        cv.isScrollEnabled = false
        cv.delegate = self
        cv.dataSource = self
        cv.registerClassCell(class: RelatedAnimeCardCell.self)
        return cv
    }()

    private var collectionViewHeightConstraint: Constraint?

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
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(titleLabel)
        contentView.addSubview(collectionView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(60)
            make.top.equalToSuperview().offset(16)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().offset(-60)
            make.bottom.equalToSuperview().offset(-16).priority(999)
            collectionViewHeightConstraint = make.height.equalTo(1).constraint
        }
    }

    private func updateCollectionViewHeight() {
        collectionView.layoutIfNeeded()
        let contentSize = waterfallLayout.collectionViewContentSize
        collectionViewHeightConstraint?.update(offset: contentSize.height)
    }

    static func estimatedHeight(for items: [BangumiIntro], width: CGFloat) -> CGFloat {
        guard !items.isEmpty else { return 0 }

        let titleHeight = NSLocalizedString("关联作品", comment: "").boundingRect(
            with: CGSize(width: width - 60 - 60, height: 60),
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.ddp_large()],
            context: nil
        ).height.rounded(.up)

        let layout = WaterfallLayout()
        layout.columnCount = 3
        let inset = layout.sectionInset
        let availableWidth = width - 60 - 60 - inset.left - inset.right
        let itemWidth = (availableWidth - layout.itemPadding * CGFloat(layout.columnCount - 1)) / CGFloat(layout.columnCount)

        var columnHeights = Array(repeating: inset.top, count: layout.columnCount)
        for item in items {
            let column = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let height = RelatedAnimeCardCell.estimatedHeight(for: item, width: itemWidth)
            columnHeights[column] = columnHeights[column] + height + layout.itemPadding
        }
        let waterfallHeight = (columnHeights.max() ?? inset.top) + inset.bottom
        return titleHeight + 16 + 12 + waterfallHeight + 16
    }
}

// MARK: - WaterfallLayoutDelegate

extension BangumiDetailRelatedCell: WaterfallLayoutDelegate {

    func waterfallLayout(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        guard indexPath.item < items.count else { return itemWidth * 0.65 }
        return RelatedAnimeCardCell.estimatedHeight(for: items[indexPath.item], width: itemWidth)
    }
}

// MARK: - RelatedAnimeCardCell

extension BangumiDetailRelatedCell {

    class RelatedAnimeCardCell: CollectionViewCell {

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

        private lazy var ratingLabel: UILabel = {
            let label = UILabel()
            label.font = .ddp_small()
            label.textColor = .mainColor
            label.textAlignment = .center
            return label
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.addSubview(posterImageView)
            contentView.addSubview(nameLabel)
            contentView.addSubview(ratingLabel)

            posterImageView.snp.makeConstraints { make in
                make.top.centerX.equalToSuperview()
                make.width.equalToSuperview()
                make.height.equalTo(posterImageView.snp.width).multipliedBy(9.0 / 16.0)
            }

            nameLabel.snp.makeConstraints { make in
                make.top.equalTo(posterImageView.snp.bottom).offset(10)
                make.leading.trailing.equalToSuperview().inset(8)
            }

            ratingLabel.snp.makeConstraints { make in
                make.top.equalTo(nameLabel.snp.bottom).offset(4)
                make.leading.trailing.equalToSuperview().inset(4)
            }
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        func configure(with item: BangumiIntro) {
            nameLabel.text = item.animeTitle
            ratingLabel.text = String(format: "%.1f", item.rating)
            ratingLabel.isHidden = item.rating <= 0
            if let url = URL(string: item.imageUrl) {
                posterImageView.kf.setImage(with: url, placeholder: UIImage.placeholder)
            }
        }

        static func estimatedHeight(for item: BangumiIntro, width: CGFloat) -> CGFloat {
            let imageHeight = width * 9.0 / 16.0
            let titleHeight = item.animeTitle.boundingRect(
                with: CGSize(width: width - 16, height: 44),
                options: .usesLineFragmentOrigin,
                attributes: [.font: UIFont.ddp_small(weight: .medium)],
                context: nil
            ).height.rounded(.up)
            let ratingHeight: CGFloat = item.rating > 0
                ? String(format: "%.1f", item.rating).boundingRect(
                    with: CGSize(width: width - 8, height: 30),
                    options: .usesLineFragmentOrigin,
                    attributes: [.font: UIFont.ddp_small()],
                    context: nil
                ).height.rounded(.up)
                : 0
            return imageHeight + 10 + titleHeight + (ratingHeight > 0 ? 4 + ratingHeight : 0)
        }
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension BangumiDetailRelatedCell: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueCell(class: RelatedAnimeCardCell.self, indexPath: indexPath)
        cell.configure(with: items[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onItemSelected?(items[indexPath.item].animeId)
    }
}
